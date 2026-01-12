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

# TODO: kwargs named test or check?
# NOTE: docstring lives in the main package under `test_explicit_imports`
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
            @testset "No implicit imports" begin
                ex = check_no_implicit_imports(package, file;
                                                throw=false,
                                                askwargs(no_implicit_imports)...)
                if ex === nothing
                    @test true
                elseif ex isa UnanalyzableModuleException
                    unanalyzable_modules = ["unanalyzable module: $(ex.mod)"]
                    if VERSION >= v"1.14"
                        @test isempty(unanalyzable_modules) context=ex.mod
                    else
                        @test isempty(unanalyzable_modules)
                    end
                else
                    missing_explicit_imports = ["using $(choose_exporter(row.name, row.exporters)): $(row.name) # at $(row.location)" for row in ex.names]
                    if VERSION >= v"1.14"
                        @test isempty(missing_explicit_imports) context=ex.mod
                    else
                        @test isempty(missing_explicit_imports)
                    end
                end
            end
        end

        if no_stale_explicit_imports !== false
            @testset "No stale explicit imports" begin
                ex = check_no_stale_explicit_imports(package, file;
                                                     throw=false,
                                                     askwargs(no_stale_explicit_imports)...)
                if ex === nothing
                    @test true
                elseif ex isa UnanalyzableModuleException
                    unanalyzable_modules = ["unanalyzable module: $(ex.mod)"]
                    if VERSION >= v"1.14"
                        @test isempty(unanalyzable_modules) context=ex.mod
                    else
                        @test isempty(unanalyzable_modules)
                    end
                else
                    stale_explicit_imports = ["unused explicit import in $(ex.mod): $(row.name) # imported at $(row.location)"
                                              for row in ex.names]
                    if VERSION >= v"1.14"
                        @test isempty(stale_explicit_imports) context=ex.mod
                    else
                        @test isempty(stale_explicit_imports)
                    end
                end
            end
        end

        if all_explicit_imports_via_owners !== false
            @testset "Explicit imports via owners" begin
                ex = check_all_explicit_imports_via_owners(package, file;
                                                           throw=false,
                                                           askwargs(all_explicit_imports_via_owners)...)
                if ex === nothing
                    @test true
                else
                    imports_from_non_owners = ["using $(row.importing_from): $(row.name) # owner $(row.whichmodule), at $(row.location)"
                                               for row in ex.bad_imports]
                    if VERSION >= v"1.14"
                        @test isempty(imports_from_non_owners) context=ex.mod
                    else
                        @test isempty(imports_from_non_owners)
                    end
                end
            end
        end

        if all_explicit_imports_are_public !== false
            @testset "Explicit imports are public" begin
                ex = check_all_explicit_imports_are_public(package, file;
                                                           throw=false,
                                                           askwargs(all_explicit_imports_are_public)...)
                if ex === nothing
                    @test true
                else
                    non_public_explicit_imports = ["using $(row.importing_from): $(row.name) # not public, at $(row.location)"
                                                   for row in ex.bad_imports]
                    if VERSION >= v"1.14"
                        @test isempty(non_public_explicit_imports) context=ex.mod
                    else
                        @test isempty(non_public_explicit_imports)
                    end
                end
            end
        end

        if all_qualified_accesses_via_owners !== false
            @testset "Qualified accesses via owners" begin
                ex = check_all_qualified_accesses_via_owners(package, file;
                                                             throw=false,
                                                             askwargs(all_qualified_accesses_via_owners)...)
                if ex === nothing
                    @test true
                else
                    qualified_accesses_from_non_owners = ["$(row.accessing_from).$(row.name) # owner $(row.whichmodule), at $(row.location)"
                                                          for row in ex.accesses]
                    if VERSION >= v"1.14"
                        @test isempty(qualified_accesses_from_non_owners) context=ex.mod
                    else
                        @test isempty(qualified_accesses_from_non_owners)
                    end
                end
            end
        end

        if all_qualified_accesses_are_public !== false
            @testset "Qualified accesses are public" begin
                ex = check_all_qualified_accesses_are_public(package, file;
                                                             throw=false,
                                                             askwargs(all_qualified_accesses_are_public)...)
                if ex === nothing
                    @test true
                else
                    non_public_qualified_accesses = ["$(row.accessing_from).$(row.name) # not public, at $(row.location)"
                                                     for row in ex.bad_imports]
                    if VERSION >= v"1.14"
                        @test isempty(non_public_qualified_accesses) context=ex.mod
                    else
                        @test isempty(non_public_qualified_accesses)
                    end
                end
            end
        end

        if no_self_qualified_accesses !== false
            @testset "No self qualified accesses" begin
                ex = check_no_self_qualified_accesses(package, file;
                                                      throw=false,
                                                      askwargs(no_self_qualified_accesses)...)
                if ex === nothing
                    @test true
                else
                    self_qualified_accesses = ["$(ex.mod).$(row.name) # at $(row.location)"
                                               for row in ex.accesses]
                    if VERSION >= v"1.14"
                        @test isempty(self_qualified_accesses) context=ex.mod
                    else
                        @test isempty(self_qualified_accesses)
                    end
                end
            end
        end
    end
end

end # TestExt
