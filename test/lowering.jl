# Scratch work - this file is not included anywhere

using ExplicitImports.Vendored.JuliaLowering, ExplicitImports.Vendored.JuliaSyntax
using .JuliaLowering: SyntaxTree, ensure_attributes, showprov
using ExplicitImports.Vendored.AbstractTrees
using ExplicitImports.Vendored.AbstractTrees: parent

# piracy
AbstractTrees.children(t::SyntaxTree) = something(JuliaSyntax.children(t), ())

include("Exporter.jl")
using Compat # dep of test_mods.jl
include("test_mods.jl")

src = read("test_mods.jl", String)
tree = parseall(JuliaLowering.SyntaxTree, src; filename="tests_mods.jl")

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

tree = parseall(JuliaLowering.SyntaxTree, src; filename="tests_mods.jl")

cchildren(x) = collect(children(x))
testmod1_code = cchildren(cchildren(tree)[2])[2]
func = cchildren(testmod1_code)[end - 1]

leaf = cchildren(func)[2]
nodevalue(leaf) # print_explicit_imports

nodevalue(AbstractTrees.parent(leaf)) # call defining f



cchildren(x) = collect(children(x))
testmod1_code = cchildren(cchildren(tree)[2])[2]
func = cchildren(testmod1_code)[end]

leaf = cchildren(cchildren(func)[2])[2]
nodevalue(leaf) #  check_no_implicit_imports as an Identifier

nodevalue(AbstractTrees.parent(leaf)) # . with ExplicitImports and check_no_implicit_imports


ex = nodevalue(testmod1_code)
ex = ensure_attributes(ex; var_id=Int)

in_mod = TestMod1
# in_mod=Main
ctx1, ex_macroexpand = JuliaLowering.expand_forms_1(in_mod, ex);
ctx2, ex_desugar = JuliaLowering.expand_forms_2(ctx1, ex_macroexpand);
ctx3, ex_scoped = JuliaLowering.resolve_scopes(ctx2, ex_desugar);

leaf = collect(Leaves(ex_scoped))[end - 3]
showprov(leaf)

global_bindings = filter(ctx3.bindings.info) do binding
    # want globals
    keep = binding.kind == :global

    # internal ones seem non-interesting (`#self#` etc)
    keep &= !binding.is_internal

    # I think we want ones that aren't assigned to? otherwise we are _defining_ the global here, not using it
    keep &= binding.n_assigned == 0
    return keep
end


# notes
# global names seem "easy": they show up as BindingID in the source tree and have an info populated in `ctx.binding.info`
# qualified names seem a bit harder, they show up like this:
#
# [call]                                   │
#   top.getproperty    :: top              │
#   #₈/ExplicitImports :: BindingId        │
#   :check_no_implicit_imports :: Symbol   │ scope_layer=1
#
# so here `check_no_implicit_imports` is a qualified name, we can see it as a child of call,
# where we are calling getproperty on ExplicitImports and `check_no_implicit_imports`.
# so if we want to check you are calling it from the "right" module, we need to follow the tree,
# find this pattern, then check the module against the symbol.
# That's what we already do, but now we should have more precision in knowing the module I think

# Ok, so something we could do is basically like what we do now in `get_names_used`:
# 1. find the leaves. Throw out anything whose `kind` isn't a BindingId or a Symbol (I think)
# 2. Symbols may be qualified; check if the parent is `.`. Then the first parent is the module(?). If not qualified then not interesting (?)
# 3. BindingIds are potential globals, and are potentially qualifying another name

leaf = collect(Leaves(TreeCursor(ex_scoped)))[end-3]
nodevalue(leaf)
nodevalue(AbstractTrees.parent(leaf))


##
using ExplicitImports.Vendored.JuliaLowering, ExplicitImports.Vendored.JuliaSyntax

src = read("issue_120.jl", String)
tree = JuliaSyntax.parseall(JuliaLowering.SyntaxTree, src; filename="issue_120.jl")
