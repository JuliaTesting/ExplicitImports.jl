using Oceananigans, ExplicitImports, Test

@testset "Oceananigans" begin
    # https://github.com/CliMA/Oceananigans.jl/blob/986acc0f61b6f5a6fa9bfd589a22c204f043186c/test/test_quality_assurance.jl#L11C1-L38C8
    modules = (Oceananigans.Utils, Oceananigans.OrthogonalSphericalShellGrids,
               Oceananigans.Diagnostics, Oceananigans.AbstractOperations,
               Oceananigans.Models.HydrostaticFreeSurfaceModels, Oceananigans.TimeSteppers,
               Oceananigans.ImmersedBoundaries, Oceananigans.TurbulenceClosures)

    @testset "Explicit Imports [$(mod)]" for mod in modules
        @info "Testing no implicit imports for module $(mod)"
        @test ExplicitImports.check_no_implicit_imports(mod) === nothing
    end

    @testset "Import via Owner" begin
        @info "Testing no imports via owner"
        @test ExplicitImports.check_all_explicit_imports_via_owners(Oceananigans) ===
              nothing
    end

    @testset "Stale Explicit Imports" begin
        @info "Testing no stale implicit imports"
        @test ExplicitImports.check_no_stale_explicit_imports(Oceananigans) === nothing
    end

    @testset "Qualified Accesses" begin
        @info "Testing no qualified access via owners"
        @test ExplicitImports.check_all_qualified_accesses_via_owners(Oceananigans) ===
              nothing
    end

    @testset "Self Qualified Accesses" begin
        @info "Testing no self qualified accesses"
        @test ExplicitImports.check_no_self_qualified_accesses(Oceananigans) === nothing
    end
end
