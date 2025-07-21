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
