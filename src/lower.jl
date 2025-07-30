# NOTE: this file was written mostly by o3, needs checking

using .JuliaSyntax: parseall, numchildren
using .JuliaLowering: SyntaxTree, MacroExpansionContext, DesugaringContext,
                      ensure_attributes, expand_forms_1, expand_forms_2, resolve_scopes,
                      reparent, ScopeLayer,
                      Bindings, IdTag, LayerId, LambdaBindings, eval_module,
                      syntax_graph, makenode, is_leaf, @K_str,
                      Bindings

"""
    lower_tree(tree, into_mod=Main) -> scoped_toplevel

Statically lowers `tree` (the result of `parseall`) **and every nested module
body it contains**, returning a single `K"toplevel"` that carries full
`BindingId` information.
"""
function lower_tree(tree::SyntaxTree, into_mod::Module=Main)
    # --- initial context --------------------------------------------------
    graph = ensure_attributes(syntax_graph(tree);
                              var_id=Int,
                              scope_layer=Int,
                              lambda_bindings=LambdaBindings,
                              bindings=Bindings)

    layers = [ScopeLayer(1, into_mod, false)]
    bindings = Bindings()
    # TODO: should the layer[1] be repeated like this? or should it be absent from layers?
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
    for stmt in js_children(blk)
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
        for c in js_children(ex)
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
        inner_ctx = _process_block!(inner_ctx, js_children(ex[4])[1], out)

        # bring back the (possibly) mutated graph/bindings but restore
        # the outer scope stack / current layer
        macro_ctx = MacroExpansionContext(inner_ctx.graph, inner_ctx.bindings,
                                          macro_ctx.scope_layers, macro_ctx.current_layer)

        # walk any remaining js_children of the original call node
        for i in 2:numchildren(ex)
            macro_ctx = _visit_nested!(macro_ctx, ex[i], out)
        end
        return macro_ctx
    end

    is_leaf(ex) && return macro_ctx
    for c in js_children(ex)
        macro_ctx = _visit_nested!(macro_ctx, c, out)
    end
    return macro_ctx
end
