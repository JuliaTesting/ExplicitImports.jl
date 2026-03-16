using Issue79Pkg
using LinearAlgebra

ext_mod = Base.get_extension(Issue79Pkg, :LinearAlgebraExt)

@testset "extension submodule analyzable (#79)" begin
    @test ext_mod !== nothing
    @test isdefined(ext_mod, :SubmoduleExt)
    @test check_no_implicit_imports(Issue79Pkg) === nothing
end
