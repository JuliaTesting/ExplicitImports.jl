using Test
subdirs = filter(isdir, readdir(@__DIR__; join=true))

@testset "Integration tests" verbose=true begin
    for dir in subdirs
        isfile(joinpath(dir, "check.jl")) || continue
        @info "Running integration tests for $(basename(dir))"
        @test success(`$(Base.julia_cmd()) --project=$dir -e 'using Pkg; Pkg.instantiate()'`)
        @test success(`$(Base.julia_cmd()) --project=$dir $dir/check.jl`)
    end
end
