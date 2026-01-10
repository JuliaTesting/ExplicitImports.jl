# Test modules for default parameter value scoping (issue #120, #62)
# These test is_in_default_parameter_value and descends_from_first_child_of

# https://github.com/JuliaTesting/ExplicitImports.jl/issues/120
module TestModIssue120
using Base: wrap_string

function f(wrap_string = wrap_string("foo", UInt32(1)))
    print(wrap_string)
end

end # TestModIssue120

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

# Case 11: Default value should see outer local scope
module TestModDefault11
using Base: RefValue
function outer()
    local_ref = RefValue(1)
    function inner(x = local_ref[])
        return x
    end
    return inner()
end
end # TestModDefault11

# Case 12: Arrow body tuple should not be treated as default params
module TestModDefault12
const f = x -> (a = x)
end # TestModDefault12

# Case 13: Prior positional argument used in default
module TestModDefault13
function f(x, y = x)
    return y
end
end # TestModDefault13

# Case 14: Current parameter not visible in its own default
module TestModDefault14
function f(x = x)
    return 1
end
end # TestModDefault14

# Case 15: Later positional parameter not visible in earlier default
module TestModDefault15
function f(x = y, y = 1)
    return x
end
end # TestModDefault15

# Case 16: Keyword default can see positional parameter
module TestModDefault16
function f(x; y = x)
    return y
end
end # TestModDefault16

# Case 17: Keyword default can see earlier keyword
module TestModDefault17
function f(; x = 1, y = x)
    return y
end
end # TestModDefault17

# Case 18: Keyword default cannot see later keyword
module TestModDefault18
function f(; y = x, x = 1)
    return y
end
end # TestModDefault18

# Case 19: Positional default cannot see keyword
module TestModDefault19
function f(y = x; x = 1)
    return y
end
end # TestModDefault19

# Case 20: Destructured positional bindings not visible in positional default
module TestModDefault20
function f((a, b), y = a)
    return y
end
end # TestModDefault20

# Case 21: Destructured positional bindings not visible in keyword default
module TestModDefault21
function f((a, b); y = a)
    return y
end
end # TestModDefault21

# Case 22: Typed prior positional parameter visible in later default
module TestModDefault22
function f(x::Int = 7, y = x)
    return y
end
end # TestModDefault22

# Case 23: Nested function literal inside default sees prior parameter
module TestModDefault23
function f(x, y = (() -> x)())
    return y
end
end # TestModDefault23

# Case 24: Varargs positional binding visible to keyword default
module TestModDefault24
function f(x...; y = x)
    return y
end
end # TestModDefault24

# Case 25: where-wrapped default should not treat param as in-scope for default
module TestModDefault25
using Base: wrap_string
function f(wrap_string::T = wrap_string("foo", UInt32(1))) where T
    return wrap_string
end
end # TestModDefault25

# Case 26: Arrow function assignment should not leak to outer scope
module TestModDefault26
function f()
    g = x -> (y = 1; y)
    return y
end
end # TestModDefault26
