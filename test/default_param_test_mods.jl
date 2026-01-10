# Test modules for default parameter value scoping (issue #120, #62)
# These test is_in_default_parameter_value and is_ancestor_first_child_of

# https://github.com/JuliaTesting/ExplicitImports.jl/issues/120
module TestMod16
using Base: wrap_string

function f(wrap_string = wrap_string("foo", UInt32(1)))
    print(wrap_string)
end

end # TestMod16

# Case 1: Type annotation on parameter - T should NOT be in default value
module TestModDefault1
using Base: RefValue
# In f(x::RefValue = default), RefValue is in the type annotation (LHS), not the default value
function f(x::RefValue = nothing)
    return x
end
end # TestModDefault1

# Case 2: Type annotation AND default value both use imported name
module TestModDefault2
using Base: RefValue
# RefValue in ::RefValue is NOT in default value
# RefValue in RefValue{Int}(1) IS in default value
function f(x::RefValue = RefValue{Int}(1))
    return x
end
end # TestModDefault2

# Case 3: Arrow function with default parameter
module TestModDefault3
using Base: wrap_string
# wrap_string in default value of arrow function
const g = (wrap_string = wrap_string("test", UInt32(1))) -> print(wrap_string)
end # TestModDefault3

# Case 4: Keyword argument with default value
module TestModDefault4
using Base: wrap_string
function f(; wrap_string = wrap_string("test", UInt32(1)))
    print(wrap_string)
end
end # TestModDefault4

# Case 5: Multiple parameters with defaults
module TestModDefault5
using Base: wrap_string, RefValue
function f(wrap_string = wrap_string("a", UInt32(1)), y::RefValue = RefValue{Int}(2))
    print(wrap_string, y)
end
end # TestModDefault5

# Case 6: Nested function call in default value
module TestModDefault6
using Base: wrap_string
function outer(x)
    return x * 2
end
function f(wrap_string = outer(wrap_string("test", UInt32(1))))
    print(wrap_string)
end
end # TestModDefault6

# Case 7: Function with parametric type in signature
module TestModDefault7
using Base: RefValue
# RefValue{T} in type annotation - RefValue should NOT be in default value
function f(x::RefValue{T} = nothing) where T
    return x
end
end # TestModDefault7

# Case 8: Typed keyword argument
module TestModDefault8
using Base: RefValue
function f(; x::RefValue = RefValue{Int}(1))
    return x
end
end # TestModDefault8

# Case 9: Default value in tuple destructuring style (short form function)
module TestModDefault9
using Base: wrap_string
f(wrap_string = wrap_string("test", UInt32(1))) = print(wrap_string)
end # TestModDefault9

# Case 10: where clause - type param T shadows import but default uses import
module TestModDefault10
using Base: RefValue
# The T in ::T refers to the where clause T, not an import
# But RefValue in default IS the import
function f(x::T = RefValue{Int}(1)) where T
    return x
end
end # TestModDefault10
