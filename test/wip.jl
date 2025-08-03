
using .JuliaLowering: SyntaxTree, ensure_attributes, showprov
using .JuliaSyntax, .JuliaLowering

src = """
module Foo129
foo() = 3
h(f) = 4
h(f, f2) = 4
module Bar
using ..Foo129: foo, h
bar() = h(foo)

# we will test that the LHS foo is a function arg and the RHS ones are not
bar2(x, foo) = h(foo, foo)
end # Bar
end # Foo129
"""

tree = parseall(JuliaLowering.SyntaxTree, src; filename="file.jl")

ctx1, ex_macroexpand = JuliaLowering.expand_forms_1(Main, tree);
ctx2, ex_desugar = JuliaLowering.expand_forms_2(ctx1, ex_macroexpand);
ctx3, ex_scoped = JuliaLowering.resolve_scopes(ctx2, ex_desugar);
ex_scoped

ex = JuliaSyntax.children(JuliaSyntax.children(tree)[1])[2]

ctx1, ex_macroexpand = JuliaLowering.expand_forms_1(Main, ex);
ctx2, ex_desugar = JuliaLowering.expand_forms_2(ctx1, ex_macroexpand);
ctx3, ex_scoped = JuliaLowering.resolve_scopes(ctx2, ex_desugar);
ex_scoped
