module TestExt
using ExplicitImports
using ExplicitImports: check_file, choose_exporter
using Test

# Borrowed from Aqua.jl
askwargs(kwargs) = (; kwargs...)
function askwargs(flag::Bool)
    if !flag
        throw(ArgumentError("expect `true`"))
    end
    return NamedTuple()
end

# NOTE: docstring lives in the main package under `test_explicit_imports`
function test_no_implicit_imports(package::Module, file=pathof(mod); kwargs...)
    @testset "No implicit imports" begin
        ex = check_no_implicit_imports(package, file; throw=false, kwargs...)
        if ex === nothing
            @test true
        elseif ex isa UnanalyzableModuleException
            unanalyzable_modules = ["unanalyzable module: $(ex.mod)"]
            @test isempty(unanalyzable_modules)
        else
            missing_explicit_imports = ["using $(choose_exporter(row.name, row.exporters)): $(row.name) # used at $(row.location)" for row in ex.names]
            @test isempty(missing_explicit_imports)
        end
    end
end

function test_no_stale_explicit_imports(package::Module, file=pathof(mod); kwargs...)
    @testset "No stale explicit imports" begin
        ex = check_no_stale_explicit_imports(package, file; throw=false, kwargs...)
        if ex === nothing
            @test true
        elseif ex isa UnanalyzableModuleException
            unanalyzable_modules = ["unanalyzable module: $(ex.mod)"]
            @test isempty(unanalyzable_modules)
        else
            stale_explicit_imports = ["unused explicit import in $(ex.mod): $(row.name) # imported at $(row.location)"
                                      for row in ex.names]
            @test isempty(stale_explicit_imports)
        end
    end
end

function test_all_explicit_imports_via_owners(package::Module, file=pathof(mod); kwargs...)
    @testset "Explicit imports via owners" begin
        ex = check_all_explicit_imports_via_owners(package, file; throw=false, kwargs...)
        if ex === nothing
            @test true
        else
            imports_from_non_owners = ["using $(row.importing_from): $(row.name) # owner $(row.whichmodule), at $(row.location)"
                                       for row in ex.bad_imports]
            @test isempty(imports_from_non_owners)
        end
    end
end

function test_all_explicit_imports_are_public(package::Module, file=pathof(mod); kwargs...)
    @testset "Explicit imports are public" begin
        ex = check_all_explicit_imports_are_public(package, file; throw=false, kwargs...)
        if ex === nothing
            @test true
        else
            non_public_explicit_imports = ["using $(row.importing_from): $(row.name) # not public, at $(row.location)"
                                           for row in ex.bad_imports]
            @test isempty(non_public_explicit_imports)
        end
    end
end

function test_all_qualified_accesses_via_owners(package::Module, file=pathof(mod); kwargs...)
    @testset "Qualified accesses via owners" begin
        ex = check_all_qualified_accesses_via_owners(package, file; throw=false, kwargs...)
        if ex === nothing
            @test true
        else
            qualified_accesses_from_non_owners = ["$(row.accessing_from).$(row.name) # owner $(row.whichmodule), at $(row.location)"
                                                  for row in ex.accesses]
            @test isempty(qualified_accesses_from_non_owners)
        end
    end
end

function test_all_qualified_accesses_are_public(package::Module, file=pathof(mod); kwargs...)
    @testset "Qualified accesses are public" begin
        ex = check_all_qualified_accesses_are_public(package, file; throw=false, kwargs...)
        if ex === nothing
            @test true
        else
            non_public_qualified_accesses = ["$(row.accessing_from).$(row.name) # not public, at $(row.location)"
                                             for row in ex.bad_imports]
            @test isempty(non_public_qualified_accesses)
        end
    end
end

function test_no_self_qualified_accesses(package::Module, file=pathof(mod); kwargs...)
    @testset "No self qualified accesses" begin
        ex = check_no_self_qualified_accesses(package, file; throw=false, kwargs...)
        if ex === nothing
            @test true
        else
            self_qualified_accesses = ["$(ex.mod).$(row.name) # at $(row.location)"
                                       for row in ex.accesses]
            @test isempty(self_qualified_accesses)
        end
    end
end

function ExplicitImports._test_explicit_imports(package::Module, file=pathof(mod);
                                                no_implicit_imports=true,
                                                no_stale_explicit_imports=true,
                                                all_explicit_imports_via_owners=true,
                                                all_explicit_imports_are_public=true,
                                                all_qualified_accesses_via_owners=true,
                                                all_qualified_accesses_are_public=true,
                                                no_self_qualified_accesses=true)
    check_file(file)

    @testset "ExplicitImports" begin
        if no_implicit_imports !== false
            test_no_implicit_imports(package, file; askwargs(no_implicit_imports)...)
        end

        if no_stale_explicit_imports !== false
            test_no_stale_explicit_imports(package, file; askwargs(no_stale_explicit_imports)...)
        end

        if all_explicit_imports_via_owners !== false
            test_all_explicit_imports_via_owners(package, file;
                                                 askwargs(all_explicit_imports_via_owners)...)
        end

        if all_explicit_imports_are_public !== false
            test_all_explicit_imports_are_public(package, file;
                                                 askwargs(all_explicit_imports_are_public)...)
        end

        if all_qualified_accesses_via_owners !== false
            test_all_qualified_accesses_via_owners(package, file;
                                                   askwargs(all_qualified_accesses_via_owners)...)
        end

        if all_qualified_accesses_are_public !== false
            test_all_qualified_accesses_are_public(package, file;
                                                   askwargs(all_qualified_accesses_are_public)...)
        end

        if no_self_qualified_accesses !== false
            test_no_self_qualified_accesses(package, file;
                                            askwargs(no_self_qualified_accesses)...)
        end
    end
end

end # TestExt
