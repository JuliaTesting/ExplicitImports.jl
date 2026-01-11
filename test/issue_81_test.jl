using Test
using ExplicitImports

issue_path = joinpath(@__DIR__, "issue_81.jl")
include(issue_path)

@testset "Cmd interpolation uses explicit imports (#81)" begin
    @test check_no_stale_explicit_imports(CmdInterpolationUsesImport, issue_path) === nothing
end
