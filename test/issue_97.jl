# https://github.com/JuliaTesting/ExplicitImports.jl/issues/97
module ArgCheck

export @argcheck

macro argcheck(ex)
    return esc(ex)
end

end # module

module Issue97

using ..ArgCheck
using ..ArgCheck: ArgCheck, @argcheck

function positive(x)
    @argcheck x > 0
    return x
end

end # module
