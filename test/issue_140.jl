# Tests for where clause type parameters not being incorrectly identified as implicit imports.
# Issue: Type parameter `I` in `where` clauses was being confused with `LinearAlgebra.I`.

module WhereTypeParamSimple
using LinearAlgebra

# Simple case: `I` is a type parameter, not LinearAlgebra's identity matrix
function foo(x::I) where {I}
    return x
end

end # module

module WhereTypeParamConstructor
using LinearAlgebra

# More complex case: parametric struct with constructor using `where` clause
struct Field{LX, LY, I, T}
    data::T
    indices::I
end

function Field{LX, LY, I, T}(data::T) where {LX, LY, I, T}
    return Field{LX, LY, I, T}(data, nothing)
end

end # module

module WhereTypeParamNested
using LinearAlgebra

# Nested where clauses
function bar(x::T, y::S) where {T} where {S}
    return x, y
end

end # module

module WhereTypeParamWithBounds
using LinearAlgebra

# Type parameter with bounds
function baz(x::T) where {T <: Number}
    return x
end

end # module

module StructWithSupertype
using LinearAlgebra

# Struct with <: supertype - type params should not be confused with globals
abstract type AbstractFoo end

struct Foo{LX, LY, I, T} <: AbstractFoo
    data::T
    indices::I
end

end # module

module StructWithSupertypeAndBounds
using LinearAlgebra

# Struct with <: supertype and type param bounds
abstract type AbstractBar end

struct Bar{I <: Integer, T <: Number} <: AbstractBar
    data::T
    index::I
end

end # module

module VarargsFunction
using LinearAlgebra

# Varargs function arguments - I should not be confused with LinearAlgebra.I
function process(data, I...)
    return data, I
end

# Method with qualified module prefix
Base.checkbounds(::Type{Int}, I...) = nothing

end # module
