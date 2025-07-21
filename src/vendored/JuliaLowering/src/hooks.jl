using ..JuliaSyntax


# Becomes `Core._lower()` upon activating JuliaLowering.  Returns an svec with
# the lowered code (usually expr) as its first element, and whatever we want
# after it, until the API stabilizes
function core_lowerer_hook(code, mod::Module, file="none", line=0, world=typemax(Csize_t), warn=false)
    if Base.isexpr(code, :syntaxtree)
        # Getting toplevel.c to check for types it doesn't know about is hard.
        # We wrap SyntaxTrees with this random expr head so that the call to
        # `jl_needs_lowering` in `jl_toplevel_eval_flex` returns true; this way
        # the SyntaxTree is handed back to us, unwraped here, and lowered.
        code = code.args[1]
    end
    if code isa Expr
        @warn("""JuliaLowering received an Expr instead of a SyntaxTree.
                 This is currently expected when evaluating modules.
                 Falling back to flisp...""",
               code=code, file=file, line=line, mod=mod)
        return Base.fl_lower(code, mod, file, line, world, warn)
    elseif !(code isa SyntaxTree)
        # LineNumberNode, Symbol, probably others...
        return Core.svec(code)
    end
    try
        ctx1, st1 = expand_forms_1(  mod,  code)
        ctx2, st2 = expand_forms_2(  ctx1, st1)
        ctx3, st3 = resolve_scopes(  ctx2, st2)
        ctx4, st4 = convert_closures(ctx3, st3)
        ctx5, st5 = linearize_ir(    ctx4, st4)
        ex = to_lowered_expr(mod, st5)
        return Core.svec(ex, st5, ctx5)
    catch exc
        @error("JuliaLowering failed — falling back to flisp!",
               exception=(exc,catch_backtrace()),
               code=code, file=file, line=line, mod=mod)
        return Base.fl_lower(st0, mod, file, line, world, warn)
    end
end

# TODO: This is code copied from JuliaSyntax, adapted to produce
# `Expr(:syntaxtree, st::SyntaxTree)`.
function core_parse_for_lowering_hook(code, filename::String, lineno::Int, offset::Int, options::Symbol)
    if Core._lower != core_lowerer_hook
        # If lowering can't handle SyntaxTree, return Expr.
        # (assumes no Core._lower function other than our core_lowerer_hook can handle SyntaxTree)
        return JuliaSyntax.core_parser_hook(code, filename, lineno, offset, options)
    end
    try
        # TODO: Check that we do all this input wrangling without copying the
        # code buffer
        if code isa Core.SimpleVector
            # The C entry points will pass us this form.
            (ptr,len) = code
            code = String(unsafe_wrap(Array, ptr, len))
        elseif !(code isa String || code isa SubString || code isa Vector{UInt8})
            # For non-Base string types, convert to UTF-8 encoding, using an
            # invokelatest to avoid world age issues.
            code = Base.invokelatest(String, code)
        end
        stream = JuliaSyntax.ParseStream(code, offset+1)
        if options === :statement || options === :atom
            # To copy the flisp parser driver:
            # * Parsing atoms      consumes leading trivia
            # * Parsing statements consumes leading+trailing trivia
            JuliaSyntax.bump_trivia(stream)
            if peek(stream) == K"EndMarker"
                # If we're at the end of stream after skipping whitespace, just
                # return `nothing` to indicate this rather than attempting to
                # parse a statement or atom and failing.
                return Core.svec(nothing, last_byte(stream))
            end
        end
        JuliaSyntax.parse!(stream; rule=options)
        if options === :statement
            JuliaSyntax.bump_trivia(stream; skip_newlines=false)
            if peek(stream) == K"NewlineWs"
                JuliaSyntax.bump(stream)
            end
        end

        if JuliaSyntax.any_error(stream)
            pos_before_comments = JuliaSyntax.last_non_whitespace_byte(stream)
            tree = JuliaSyntax.build_tree(SyntaxNode, stream, first_line=lineno, filename=filename)
            tag = JuliaSyntax._incomplete_tag(tree, pos_before_comments)
            exc = JuliaSyntax.ParseError(stream, filename=filename, first_line=lineno,
                                         incomplete_tag=tag)
            msg = sprint(showerror, exc)
            error_ex = Expr(tag === :none ? :error : :incomplete,
                            Meta.ParseError(msg, exc))
            ex = if options === :all
                # When encountering a toplevel error, the reference parser
                # * truncates the top level expression arg list before that error
                # * includes the last line number
                # * appends the error message
                topex = Expr(tree)
                @assert topex.head == :toplevel
                i = findfirst(JuliaSyntax._has_nested_error, topex.args)
                if i > 1 && topex.args[i-1] isa LineNumberNode
                    i -= 1
                end
                resize!(topex.args, i-1)
                _,errort = JuliaSyntax._first_error(tree)
                push!(topex.args, LineNumberNode(JuliaSyntax.source_line(errort), filename))
                push!(topex.args, error_ex)
                topex
            else
                error_ex
            end
        else
            # See unwrapping of `:syntaxtree` above.
            ex = Expr(:syntaxtree, JuliaSyntax.build_tree(SyntaxTree, stream; filename=filename, first_line=lineno))
        end

        # Note the next byte in 1-based indexing is `last_byte(stream) + 1` but
        # the Core hook must return an offset (ie, it's 0-based) so the factors
        # of one cancel here.
        last_offset = last_byte(stream)

        # Rewrap result in an svec for use by the C code
        return Core.svec(ex, last_offset)
    catch exc
        @error("""JuliaSyntax parser failed — falling back to flisp!
                  This is not your fault. Please submit a bug report to https://github.com/JuliaLang/JuliaSyntax.jl/issues""",
               exception=(exc,catch_backtrace()),
               offset=offset,
               code=code)

        Base.fl_parse(code, filename, lineno, offset, options)
    end
end

const _has_v1_13_hooks = isdefined(Core, :_lower)

function activate!(enable=true)
    if !_has_v1_13_hooks
        error("Cannot use JuliaLowering without `Core._lower` binding or in $VERSION < 1.13")
    end

    if enable
        if !isnothing(Base.active_repl_backend)
            # TODO: These act on parsed exprs, which we don't have.
            # Reimplementation needed (e.g. for scoping rules).
            empty!(Base.active_repl_backend.ast_transforms)
        end

        Core._setlowerer!(core_lowerer_hook)
        Core._setparser!(core_parse_for_lowering_hook)
    else
        Core._setlowerer!(Base.fl_lower)
        Core._setparser!(JuliaSyntax.core_parse_hook)
    end
end
