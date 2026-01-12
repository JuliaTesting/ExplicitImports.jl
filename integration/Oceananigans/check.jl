using Oceananigans, ExplicitImports, Test

@testset "Oceananigans" begin

    # https://github.com/CliMA/Oceananigans.jl/blob/8a67381e173a68e6538ab778f20c288761d014c1/test/test_quality_assurance.jl#L16-L73
    modules = (
        Oceananigans.Advection,
        Oceananigans.Architectures,
        Oceananigans.BoundaryConditions,
        Oceananigans.DistributedComputations,
        Oceananigans.Grids,
        Oceananigans.Logger,
        Oceananigans.Models,
        Oceananigans.MultiRegion,
        Oceananigans.OutputReaders,
        Oceananigans.OutputWriters,
        Oceananigans.Simulations,
        Oceananigans.StokesDrifts,
    )

    @testset "Explicit Imports" begin
        @info "Testing no implicit imports"
        @test ExplicitImports.check_no_implicit_imports(Oceananigans; ignore=modules) === nothing
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
