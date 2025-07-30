# Since we mostly care about identifiers, our parsing strategy will be:
# 1. Parse into `SyntaxNode` with JuliaSyntax
# 2. use an `AbstractTrees.TreeCursor` so we can navigate up (i.e. from leaf to root), not just down, the parse tree
# 3. Use `AbstractTrees.Leaves` to find all the leaves (which is where the identifiers are)
# 4. Find the identifiers, then traverse up (via `AbstractTrees.parent`) to check what is true about the identifier
#    such as if it's a local variable, function argument, if it is qualified, etc.

# We define a new tree that wraps a `SyntaxNode`.
# For this tree, we we add an `AbstractTrees` `children` method to traverse `include` statements to span our tree across files.
struct SyntaxNodeWrapper
    node::JuliaLowering.SyntaxTree
    file::String
    bad_locations::Set{String}
    context::Any
    in_mod::Module
end

function Base.show(io::IO, n::SyntaxNodeWrapper)
    print(io, "SyntaxNodeWrapper: ")
    show(io, n.node)
end

function Base.show(io::IO, mime::MIME"text/plain", n::SyntaxNodeWrapper)
    print(io, "SyntaxNodeWrapper: ")
    show(io, mime, n.node)
    print(io, "File: ", n.file)
end

const OFF = "#! explicit-imports: off"
const ON = "#! explicit-imports: on"

function SyntaxNodeWrapper(file::AbstractString, in_mod::Module; bad_locations=Set{String}())
    stripped = IOBuffer()
    on = true
    for line in eachline(file; keep=true)
        if strip(line) == OFF
            on = false
        end

        if strip(line) == ON
            on = true
        end

        if on
            write(stripped, line)
        end
    end
    contents = String(take!(stripped))
    parsed = JuliaSyntax.parseall(JuliaLowering.SyntaxTree, contents; ignore_warnings=true)

    # Perform lowering on the parse tree until scoping
    ex = JuliaLowering.ensure_attributes(parsed; var_id=Int)
    ctx1, ex_macroexpand = JuliaLowering.expand_forms_1(in_mod, ex)
    ctx2, ex_desugar = JuliaLowering.expand_forms_2(ctx1, ex_macroexpand)
    ctx3, ex_scoped = JuliaLowering.resolve_scopes(ctx2, ex_desugar)

    return SyntaxNodeWrapper(ex_scoped, file, bad_locations, ctx3, in_mod)
end

function try_parse_wrapper(file::AbstractString, mod::Module; bad_locations)
    return try
        SyntaxNodeWrapper(file, mod; bad_locations)
    catch e
        msg = "Error when parsing file. Skipping this file."
        @error msg file exception = (e, catch_backtrace())
        nothing
    end
end

# string representation of the location of the node
# this prints in a format where if it shows up in the VSCode terminal, you can click it
# to jump to the file
function location_str(wrapper::SyntaxNodeWrapper)
    line, col = JuliaSyntax.source_location(wrapper.node)
    return "$(wrapper.file):$line:$col"
end

struct SkippedFile
    # location of the file being skipped
    # (we don't include the file itself, since we may not know what it is)
    location::Union{String}
end

AbstractTrees.children(::SkippedFile) = ()

# Here we define children such that if we get to a static `include`, we just recurse
# into the parse tree of that file.
# This function has become increasingly horrible in the name of robustness
function AbstractTrees.children(wrapper::SyntaxNodeWrapper)
    node = wrapper.node
    if JuliaSyntax.kind(node) == K"call"
        children = js_children(node)
        if length(children) == 2
            f, arg = children #::Vector{JuliaSyntax.SyntaxNode} # make JET happy
            if try_get_val(f) === :include
                location = location_str(wrapper)
                if location in wrapper.bad_locations
                    return [SkippedFile(location)]
                end
                if JuliaSyntax.kind(arg) == K"string"
                    children = js_children(arg)
                    # if we have interpolation, there may be >1 child
                    length(children) == 1 || @goto dynamic
                    c = only(children)
                    # if we have interpolation, this might not be a string
                    kind(c) == K"String" || @goto dynamic
                    # The children of a static include statement is the entire file being included
                    # @show c typeof(c) propertynames(c)
                    new_file = joinpath(dirname(wrapper.file), c.value)
                    if isfile(new_file)
                        # @debug "Recursing into `$new_file`" node wrapper.file
                        new_wrapper = try_parse_wrapper(new_file, wrapper.in_mod; wrapper.bad_locations)
                        if new_wrapper === nothing
                            push!(wrapper.bad_locations, location)
                            return [SkippedFile(location)]
                        else
                            return [new_wrapper]
                        end
                    else
                        @warn "`include` at $location points to missing file; cannot recurse into it."
                        push!(wrapper.bad_locations, location)
                        return [SkippedFile(location)]
                    end
                else
                    @label dynamic
                    @warn "Dynamic `include` found at $location; not recursing"
                    push!(wrapper.bad_locations, location)
                    return [SkippedFile(location)]
                end
            end
        end
    end
    return map(n -> SyntaxNodeWrapper(n, wrapper.file, wrapper.bad_locations,
                                      wrapper.context, wrapper.in_mod),
               js_children(node))
end

js_children(n::Union{TreeCursor,SyntaxNodeWrapper}) = js_children(js_node(n))

# https://github.com/JuliaLang/JuliaSyntax.jl/issues/557
function js_children(n::Union{JuliaSyntax.SyntaxNode,JuliaLowering.SyntaxTree})
    return something(JuliaSyntax.children(n), ())
end

js_node(n::SyntaxNodeWrapper) = n.node
js_node(n::TreeCursor) = js_node(nodevalue(n))

function kind(n::Union{JuliaSyntax.SyntaxNode,JuliaSyntax.GreenNode,JuliaSyntax.SyntaxHead,
                       JuliaLowering.SyntaxTree})
    return JuliaSyntax.kind(n)
end
kind(n::Union{TreeCursor,SyntaxNodeWrapper}) = kind(js_node(n))

head(n::Union{JuliaSyntax.SyntaxNode,JuliaSyntax.GreenNode}) = JuliaSyntax.head(n)
head(n::Union{TreeCursor,SyntaxNodeWrapper}) = head(js_node(n))

get_val(n::JuliaLowering.SyntaxTree) = Symbol(n.name_val)
get_val(n::JuliaSyntax.SyntaxNode) = n.val
get_val(n::Union{TreeCursor,SyntaxNodeWrapper}) = get_val(js_node(n))

function try_get_val(n::JuliaLowering.SyntaxTree)
    return hasproperty(n, :name_val) ? Symbol(n.name_val) : nothing
end
try_get_val(n::JuliaSyntax.SyntaxNode) = n.val
try_get_val(n::Union{TreeCursor,SyntaxNodeWrapper}) = try_get_val(js_node(n))

function has_flags(n::Union{JuliaSyntax.SyntaxNode,
                            JuliaSyntax.GreenNode,
                            JuliaLowering.SyntaxTree}, args...)
    return JuliaSyntax.has_flags(n, args...)
end
has_flags(n::Union{TreeCursor,SyntaxNodeWrapper}, args...) = has_flags(js_node(n), args...)

# which child are we of our parent
function child_index(n::TreeCursor)
    p = parent(n)
    isnothing(p) && return error("No parent!")
    index = findfirst(==(js_node(n)), js_children(p))
    @assert !isnothing(index)
    return index
end

kind_match(k1::JuliaSyntax.Kind, k2::JuliaSyntax.Kind) = k1 == k2

parents_match(n::TreeCursor, kinds::Tuple{}) = true
function parents_match(n::TreeCursor, kinds::Tuple)
    k = first(kinds)
    p = parent(n)
    isnothing(p) && return false
    kind_match(kind(p), k) || return false
    return parents_match(p, Base.tail(kinds))
end

function parent_kinds(n::TreeCursor)
    kinds = []
    while true
        n = parent(n)
        n === nothing && return kinds
        push!(kinds, kind(n))
    end
    return kinds
end

function get_parent(n, i=1)
    for _ in i:-1:1
        n = parent(n)
        n === nothing && error("No parent")
    end
    return n
end

function has_parent(n, i=1)
    for _ in i:-1:1
        n = parent(n)
        n === nothing && return false
    end
    return true
end

# these would be piracy, but we've vendored AbstractTrees so it's technically fine
function Base.show(io::IO, cursor::AbstractTrees.ImplicitCursor)
    print(io, "ImplicitCursor: ")
    return show(io, nodevalue(cursor))
end
function Base.show(io::IO, mime::MIME"text/plain", cursor::AbstractTrees.ImplicitCursor)
    print(io, "ImplicitCursor: ")
    return show(io, mime, nodevalue(cursor))
end

function Base.show(io::IO, mime::MIME"text/plain",
                   ctx::JuliaLowering.VariableAnalysisContext)
    println(io,
            """VariableAnalysisContext with module $(ctx.mod) and
            - $(length(ctx.bindings.info)) bindings
            - $(length(ctx.closure_bindings)) closure bindings
            - $(length(ctx.closure_bindings)) lambda bindings
            - $(length(ctx.method_def_stack))-long method def stack
            and graph:""")
    return show(io, mime, ctx.graph)
end
