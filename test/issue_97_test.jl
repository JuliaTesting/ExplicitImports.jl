issue_path = joinpath(@__DIR__, "issue_97.jl")
include(issue_path)

@testset "Issue #97: macro explicit imports" begin
    # Issue97 does `using ..ArgCheck` plus `using ..ArgCheck: ArgCheck, @argcheck`.
    # The macro is explicitly imported, so check_no_implicit_imports should pass.
    @test check_no_implicit_imports(Issue97, issue_path) === nothing
    @test check_no_stale_explicit_imports(Issue97, issue_path) === nothing

    analysis = ExplicitImports.get_names_used(issue_path).per_usage_info
    argcheck_usages = filter(analysis) do nt
        nt.name == Symbol("@argcheck") && nt.module_path == [:Issue97]
    end

    @test getfield.(argcheck_usages, :analysis_code) ==
          [ExplicitImports.IgnoredImportRHS, ExplicitImports.External]
end
