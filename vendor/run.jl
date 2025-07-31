using PackageAnalyzer, UUIDs

function get_tree_hash(repo="JuliaLang/JuliaSyntax.jl", rev="46723f0")
     return readchomp(`gh api "repos/$repo/commits/$rev" --jq '.commit.tree.sha'`)
end

deps = [PackageAnalyzer.Added(; name="JuliaSyntax",
                              uuid=UUID("70703baa-626e-46a2-a12c-08ffd08c73b4"),
                              path="",
                              repo_url="https://github.com/JuliaLang/JuliaSyntax.jl",
                              # get_tree_hash("JuliaLang/JuliaSyntax.jl", "46723f0")
                              tree_hash="0d4b3dab95018bcf3925204475693d9f09dc45b8",
                              subdir=""),
        find_package("AbstractTrees"; version=v"0.4.5"),
        PackageAnalyzer.Added(; name="JuliaLowering",
                              uuid=UUID("f3c80556-a63f-4383-b822-37d64f81a311"),
                              path="",
                              repo_url="https://github.com/ericphanson/JuliaLowering.jl",
                              tree_hash = get_tree_hash("mlechu/JuliaLowering.jl", "eph/trunk"),
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
                               "using JuliaLowering" => "",
                               # for some reason Revise seems to need this:
                               "_include(path::AbstractString) = Base.include(JuliaLowering, path)" => "_include(path::AbstractString) = Base.include(JuliaLowering, joinpath(@__DIR__, path))")
            chmod(joinpath(root, file), 0o666) # make writable
            write(abspath(joinpath(root, file)), contents)
            chmod(joinpath(root, file), 0o444) # back to read-only
        end
    end
end
