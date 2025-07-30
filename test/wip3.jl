using ExplicitImports
using ExplicitImports.Vendored.JuliaLowering
using ExplicitImports.Vendored.JuliaSyntax
using .JuliaSyntax: parseall, children, numchildren
using .JuliaLowering: SyntaxTree, MacroExpansionContext, DesugaringContext,
                      ensure_attributes, expand_forms_1, expand_forms_2, resolve_scopes,
                      reparent, ScopeLayer,
                      Bindings, IdTag, LayerId, LambdaBindings, eval_module,
                      syntax_graph, children, kind, makenode, is_leaf, @K_str,
                      Bindings

"""
    lower_file(tree, into_mod=Main) -> scoped_toplevel

Statically lowers `tree` (the result of `parseall`) **and every nested module
body it contains**, returning a single `K"toplevel"` that carries full
`BindingId` information.
"""
function lower_file(tree::SyntaxTree, into_mod::Module=Main)
    # --- initial context --------------------------------------------------
    graph = ensure_attributes(syntax_graph(tree);
                              var_id=Int,
                              scope_layer=Int,
                              lambda_bindings=LambdaBindings,
                              bindings=Bindings)

    layers = [ScopeLayer(1, into_mod, false)]
    bindings = Bindings()
    ctx = MacroExpansionContext(graph, bindings, layers, layers[1])

    resolved = SyntaxTree[]
    last_ctx = _process_block!(ctx, tree, resolved)

    # stitch everything back together so callers get one tree
    return makenode(last_ctx, tree, K"toplevel", resolved...), last_ctx
end

# -------------------------------------------------------------------------
# Internal helpers
# -------------------------------------------------------------------------

function _process_block!(macro_ctx, blk, out)
    for stmt in children(blk)
        macro_ctx = _process_stmt!(macro_ctx, stmt, out)   # ← keep the new ctx
    end
    return macro_ctx
end

function _process_stmt!(macro_ctx, stmt, out)
    ctx1  = MacroExpansionContext(macro_ctx.graph, macro_ctx.bindings,
                                  macro_ctx.scope_layers, macro_ctx.current_layer)

    ex1            = expand_forms_1(ctx1, stmt)
    ctx2           = DesugaringContext(ctx1)
    ex2            = expand_forms_2(ctx2, ex1)
    ctx3, ex3      = resolve_scopes(ctx2, ex2)

    push!(out, ex3)

    # Wrap the *richer* graph / bindings in a fresh context
    next_ctx = MacroExpansionContext(ctx3.graph, ctx3.bindings,
                                     macro_ctx.scope_layers, macro_ctx.current_layer)

    # Depth-first search for nested modules
    return _visit_nested!(next_ctx, ex3, out)     # returns an updated context
end

function _visit_nested!(macro_ctx, ex, out)
    k = kind(ex)

    if k == K"inert"
        for c in children(ex)
            macro_ctx = _visit_nested!(macro_ctx, c, out)
        end
        return macro_ctx
    end

    if k == K"call" &&
       kind(ex[1]) == K"Value" && ex[1].value === eval_module &&
       kind(ex[4]) == K"inert"

        parent  = (kind(ex[2]) == K"Value" && ex[2].value isa Module) ?
                    ex[2].value : Main
        modname = Symbol(ex[3].value)

        childmod = Base.isdefined(parent, modname) ?
                     getfield(parent, modname) :
                     ( @warn "Module $modname not found in $(parent); using dummy." ;
                       Module(modname) )

        new_layer     = ScopeLayer(length(macro_ctx.scope_layers)+1, childmod, false)
        scope_layers′ = [macro_ctx.scope_layers; new_layer]

        inner_ctx = MacroExpansionContext(macro_ctx.graph, macro_ctx.bindings,
                                          scope_layers′, new_layer)

        # recurse into the body of the nested module
        inner_ctx = _process_block!(inner_ctx, children(ex[4])[1], out)

        # bring back the (possibly) mutated graph/bindings but restore
        # the outer scope stack / current layer
        macro_ctx = MacroExpansionContext(inner_ctx.graph, inner_ctx.bindings,
                                          macro_ctx.scope_layers, macro_ctx.current_layer)

        # walk any remaining children of the original call node
        for i in 2:numchildren(ex)
            macro_ctx = _visit_nested!(macro_ctx, ex[i], out)
        end
        return macro_ctx
    end

    is_leaf(ex) && return macro_ctx
    for c in children(ex)
        macro_ctx = _visit_nested!(macro_ctx, c, out)
    end
    return macro_ctx
end

src = """
module Foo129
foo() = 3
h(f) = 4

global_xyz = 1

module Bar
    using ..Foo129: foo, h, global_xyz
    bar() = h(foo)
    bar2(x, foo) = h(foo)
    bar3() = global_xyz + 1
end # Bar
end # Foo129
"""

eval(Meta.parse(src))

# 1. Parse the entire file content.
tree = parseall(SyntaxTree, src; filename="file.jl")

scoped, ctx = lower_file(tree, Main)


global_bindings = filter(ctx.bindings.info) do binding
    # want globals
    keep = binding.kind == :global

    # internal ones seem non-interesting (`#self#` etc)
    keep &= !binding.is_internal

    # I think we want ones that aren't assigned to? otherwise we are _defining_ the global here, not using it
    keep &= binding.n_assigned == 0
    return keep
end
