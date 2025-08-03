using ExplicitImports
using ExplicitImports.Vendored.JuliaLowering, ExplicitImports.Vendored.JuliaSyntax

using .JuliaLowering: SyntaxTree, MacroExpansionContext, DesugaringContext, reparent
using .JuliaSyntax, .JuliaLowering

using .JuliaSyntax: children

src = """
module Foo129
foo() = 3
h(f) = 4
module Bar
    using ..Foo129: foo, h
    bar() = h(foo)
    bar2(x, foo) = h(foo)
end # Bar
end # Foo129
"""

# 1. Parse the entire file content.
tree = parseall(SyntaxTree, src; filename="file.jl")

# 2. Set up an initial context. This context will be updated as we process
#    each top-level statement.
graph = JuliaLowering.ensure_attributes(JuliaLowering.syntax_graph(tree),
                                        var_id=Int, scope_layer=Int,
                                        # and any other attributes your passes need...
                                        lambda_bindings=JuliaLowering.LambdaBindings)
layers = [JuliaLowering.ScopeLayer(1, Main, false)]
bindings = JuliaLowering.Bindings()
# This `macro_ctx` will be updated after each statement.
macro_ctx = MacroExpansionContext(graph, bindings, layers, layers[1])

resolved_expressions = []

# 3. Iterate through top-level statements, threading the context.
@show children(tree)
for stmt in children(tree)
    println("hi")
    # Use the context from the previous step.
    current_macro_ctx = MacroExpansionContext(macro_ctx.graph, macro_ctx.bindings,
                                              macro_ctx.scope_layers, macro_ctx.current_layer)

    ex1 = JuliaLowering.expand_forms_1(current_macro_ctx, stmt)
    ctx2 = DesugaringContext(current_macro_ctx)
    ex2 = JuliaLowering.expand_forms_2(ctx2, ex1)

    # This is the key step that resolves bindings.
    ctx3, ex3 = JuliaLowering.resolve_scopes(ctx2, ex2)
    push!(resolved_expressions, ex3)

    # 4. Update the main context with the results from the statement we just processed.
    # The `bindings` and `scope_layers` tables have been mutated by the lowering passes.
    global macro_ctx
    macro_ctx = MacroExpansionContext(ctx3.graph, ctx3.bindings, current_macro_ctx.scope_layers,
                                  current_macro_ctx.current_layer) # Top-level layer doesn't change
    global tree
    tree = reparent(macro_ctx, tree)
    @show children(tree)
end

# Now, `resolved_expressions` is a vector of fully-scoped trees for each top-level statement,
# and `macro_ctx.bindings` contains the complete binding table for the entire file.
# You can now analyze these resolved trees.
combined_tree = JuliaLowering.makenode(macro_ctx, tree, K"toplevel",
                                       resolved_expressions...)
