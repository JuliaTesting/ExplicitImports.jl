using Test

selected_dirs = if isempty(ARGS)
    filter(isdir, readdir(@__DIR__; join=true))
else
    map(ARGS) do arg
        dir = isdir(arg) ? arg : joinpath(@__DIR__, arg)
        isdir(dir) || error("Integration project not found: $(arg)")
        abspath(dir)
    end
end

@testset "Integration tests" verbose=true begin
    for dir in selected_dirs
        isfile(joinpath(dir, "check.jl")) || continue
        @info "Running integration tests for $(basename(dir))"
        run(`$(Base.julia_cmd()) --project=$dir -e 'using Pkg; Pkg.instantiate()'`)
        run(`$(Base.julia_cmd()) --project=$dir $dir/check.jl`)
    end
end
