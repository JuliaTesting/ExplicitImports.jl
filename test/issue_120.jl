module Foo120

using Base: wrap_string

function f(wrap_string = wrap_string("foo", UInt32(1)))
    print(wrap_string)
end

end
