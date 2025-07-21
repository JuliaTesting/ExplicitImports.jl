module Foo129
foo() = 3
h(f) = 4
module Bar
using ..Foo129: foo, h
bar() = h(foo)
end # Bar
end # Foo129
