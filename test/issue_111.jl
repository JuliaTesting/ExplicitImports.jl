module HelloSource

hello() = "Hello, World!"

end # module

module FieldNameInnerConstructor

using ..HelloSource: hello

struct Foo
    hello::String
    Foo() = new(hello())
end

end # module

module MutableFieldNameInnerConstructor

using ..HelloSource: hello

mutable struct Foo
    hello::String
    Foo() = new(hello())
end

end # module

module KwdefFieldDefault

using ..HelloSource: hello

Base.@kwdef struct Foo
    hello::String = hello()
end

end # module

module FieldNameOnly

using ..HelloSource: hello

struct Foo
    hello::String
end

end # module

module UntypedFieldNameOnly

using ..HelloSource: hello

struct Foo
    hello
end

end # module
