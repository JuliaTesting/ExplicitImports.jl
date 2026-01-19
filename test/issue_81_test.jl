using Test
using ExplicitImports

issue_path = joinpath(@__DIR__, "issue_81.jl")
include(issue_path)

@testset "Cmd interpolation uses explicit imports (#81)" begin
    @test check_no_stale_explicit_imports(CmdInterpolationUsesImport, issue_path) === nothing
    @test check_no_stale_explicit_imports(CmdInterpolationUsesImportQuoted, issue_path) === nothing
    @test check_no_stale_explicit_imports(CmdInterpolationUsesImportNested, issue_path) === nothing
    @test check_no_stale_explicit_imports(CmdInterpolationUsesImportAdjacent, issue_path) === nothing
    @test_throws ExplicitImports.StaleImportsException check_no_stale_explicit_imports(
        CmdInterpolationUsesImportQuotedLiteral,
        issue_path)
end
