module TestExt
using ExplicitImports
using ExplicitImports: check_file
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
            @test check_no_implicit_imports(package, file;
                                            askwargs(no_implicit_imports)...) ===
                  nothing
        end

        if no_stale_explicit_imports !== false
            @test check_no_stale_explicit_imports(package, file;
                                                  askwargs(no_stale_explicit_imports)...) ===
                  nothing
        end

        if all_explicit_imports_via_owners !== false
            @test check_all_explicit_imports_via_owners(package, file;
                                                        askwargs(all_explicit_imports_via_owners)...) ===
                  nothing
        end

        if all_explicit_imports_are_public !== false
            @test check_all_explicit_imports_are_public(package, file;
                                                        askwargs(all_explicit_imports_are_public)...) ===
                  nothing
        end

        if all_qualified_accesses_via_owners !== false
            @test check_all_qualified_accesses_via_owners(package, file;
                                                          askwargs(all_qualified_accesses_via_owners)...) ===
                  nothing
        end

        if all_qualified_accesses_are_public !== false
            @test check_all_qualified_accesses_are_public(package, file;
                                                          askwargs(all_qualified_accesses_are_public)...) ===
                  nothing
        end

        if no_self_qualified_accesses !== false
            @test check_no_self_qualified_accesses(package, file;
                                                   askwargs(no_self_qualified_accesses)...) ===
                  nothing
        end
    end
end

end # TestExt
