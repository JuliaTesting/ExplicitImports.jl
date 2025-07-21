using PackageAnalyzer, UUIDs

deps = [find_package("JuliaSyntax"; version=v"1.0.2"),
        find_package("AbstractTrees"; version=v"0.4.5"),
        PackageAnalyzer.Added(; name="JuliaLowering",
                              uuid=UUID("f3c80556-a63f-4383-b822-37d64f81a311"),
                              path="",
                              repo_url="https://github.com/mlechu/JuliaLowering.jl",
                              tree_hash="2d3dfe83e9be4318c056ed9df2d3788f5723bb9d",
                              subdir="")]

for pkg in deps
    code_dir, reachable, _ = PackageAnalyzer.obtain_code(pkg)
    name, _ = PackageAnalyzer.parse_project(code_dir)
    @assert reachable
    vendor_dir = mkpath(joinpath(@__DIR__, "..", "src", "vendored", name))
    # remove any existing files
    if isdir(vendor_dir)
        rm(vendor_dir; recursive=true, force=true)
    end
    mkpath(joinpath(vendor_dir, "src"))
    cp(joinpath(code_dir, "src"), joinpath(vendor_dir, "src"); force=true)

    # patch `using JuliaSyntax` => `using ..JuliaSyntax`
    for (root, dirs, files) in walkdir(joinpath(vendor_dir, "src"))
        for file in files
            endswith(file, ".jl") || continue
            contents = replace(read(joinpath(root, file), String),
                               "using JuliaSyntax" => "using ..JuliaSyntax",
                               # remove unnecessary `using JuliaLowering` from src/hooks.jl
                               "using JuliaLowering" => "")
            chmod(joinpath(root, file), 0o666) # make writable
            write(abspath(joinpath(root, file)), contents)
            chmod(joinpath(root, file), 0o444) # back to read-only
        end
    end
end
