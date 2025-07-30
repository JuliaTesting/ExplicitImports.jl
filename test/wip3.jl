using ExplicitImports
using ExplicitImports: lower_tree
using ExplicitImports.Vendored.JuliaLowering
using ExplicitImports.Vendored.JuliaSyntax
using .JuliaSyntax: parseall, children, numchildren
using .JuliaLowering: SyntaxTree

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

scoped, ctx = lower_tree(tree, Main)


global_bindings = filter(ctx.bindings.info) do binding
    # want globals
    keep = binding.kind == :global

    # internal ones seem non-interesting (`#self#` etc)
    keep &= !binding.is_internal

    # I think we want ones that aren't assigned to? otherwise we are _defining_ the global here, not using it
    keep &= binding.n_assigned == 0
    return keep
end
