using PackageAnalyzer

deps = [("JuliaSyntax", v"1.0.2"),
        ("AbstractTrees", v"0.4.5")]

for (name, version)  in deps
    pkg = find_package(name; version)
    local_path, reachable, _ = PackageAnalyzer.obtain_code(pkg)
    @assert reachable
    p = mkpath(joinpath(@__DIR__, "..", "ExplicitImports", "vendored", name, "src"))
    cp(joinpath(local_path, "src"), p; force=true)
end
