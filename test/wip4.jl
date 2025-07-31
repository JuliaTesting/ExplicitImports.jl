using ExplicitImports.Vendored.JuliaLowering, ExplicitImports.Vendored.JuliaSyntax

using .JuliaLowering: JuliaLowering, SyntaxTree
using .JuliaSyntax: parsestmt


src = """
function Base.:(==)(a::SyntaxNodeList, b::SyntaxNodeList)
    return map(objectid, a.nodes) == map(objectid, b.nodes)
end
"""

tree = parsestmt(SyntaxTree, src; filename="file.jl")
ctx1, ex_macroexpand = JuliaLowering.expand_forms_1(Main, tree);
ctx2, ex_desugar = JuliaLowering.expand_forms_2(ctx1, ex_macroexpand);
ctx3, ex_scoped = JuliaLowering.resolve_scopes(ctx2, ex_desugar);
ex_scoped
