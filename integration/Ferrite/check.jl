using Ferrite, ExplicitImports, Metis, BlockArrays
# modified from
# https://github.com/Ferrite-FEM/Ferrite.jl/blob/3b19a33331fa0b8a93b5e7adfe2339766b5c4af4/.github/workflows/Check.yml#L55-L73
# to ignore `(:(×), :(⊗), :(⊡), :(⋅))`

allow_unanalyzable = (ColoringAlgorithm,) # baremodules
check_no_implicit_imports(Ferrite; allow_unanalyzable, ignore=(:(×), :(⊗), :(⊡), :(⋅)))
check_no_stale_explicit_imports(Ferrite; allow_unanalyzable)
check_all_qualified_accesses_via_owners(Ferrite)
check_no_self_qualified_accesses(Ferrite)
# Check extension modules
for ext in (:FerriteBlockArrays, :FerriteMetis)
    extmod = Base.get_extension(Ferrite, ext)
    if extmod !== nothing
        check_no_implicit_imports(extmod)
        check_no_stale_explicit_imports(extmod)
        check_all_qualified_accesses_via_owners(extmod)
        check_no_self_qualified_accesses(extmod)
    else
        @warn "$(ext) extensions not available."
    end
end
