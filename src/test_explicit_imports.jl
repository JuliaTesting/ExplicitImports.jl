# Borrowed from Aqua.jl
askwargs(kwargs) = (; kwargs...)
function askwargs(flag::Bool)
    if !flag
        throw(ArgumentError("expect `true`"))
    end
    return NamedTuple()
end

"""
    test_no_implicit_imports(package::Module, file=pathof(package); kwargs...)

Test.jl wrapper for [`check_no_implicit_imports`](@ref); see that function for behavior and keyword arguments.
"""
function test_no_implicit_imports(package::Module, file=pathof(package); kwargs...)
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

"""
    test_no_stale_explicit_imports(package::Module, file=pathof(package); kwargs...)

Test.jl wrapper for [`check_no_stale_explicit_imports`](@ref); see that function for behavior and keyword arguments.
"""
function test_no_stale_explicit_imports(package::Module, file=pathof(package); kwargs...)
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

"""
    test_all_explicit_imports_via_owners(package::Module, file=pathof(package); kwargs...)

Test.jl wrapper for [`check_all_explicit_imports_via_owners`](@ref); see that function for behavior and keyword arguments.
"""
function test_all_explicit_imports_via_owners(package::Module, file=pathof(package); kwargs...)
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

"""
    test_all_explicit_imports_are_public(package::Module, file=pathof(package); kwargs...)

Test.jl wrapper for [`check_all_explicit_imports_are_public`](@ref); see that function for behavior and keyword arguments.
"""
function test_all_explicit_imports_are_public(package::Module, file=pathof(package); kwargs...)
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

"""
    test_all_qualified_accesses_via_owners(package::Module, file=pathof(package); kwargs...)

Test.jl wrapper for [`check_all_qualified_accesses_via_owners`](@ref); see that function for behavior and keyword arguments.
"""
function test_all_qualified_accesses_via_owners(package::Module, file=pathof(package); kwargs...)
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

"""
    test_all_qualified_accesses_are_public(package::Module, file=pathof(package); kwargs...)

Test.jl wrapper for [`check_all_qualified_accesses_are_public`](@ref); see that function for behavior and keyword arguments.
"""
function test_all_qualified_accesses_are_public(package::Module, file=pathof(package); kwargs...)
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

"""
    test_no_self_qualified_accesses(package::Module, file=pathof(package); kwargs...)

Test.jl wrapper for [`check_no_self_qualified_accesses`](@ref); see that function for behavior and keyword arguments.
"""
function test_no_self_qualified_accesses(package::Module, file=pathof(package); kwargs...)
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



"""
    test_explicit_imports(package::Module, file=pathof(package); kw...)

Run the following checks:

* [`check_no_implicit_imports`](@ref)
* [`check_no_stale_explicit_imports`](@ref)
* [`check_all_explicit_imports_via_owners`](@ref)
* [`check_all_explicit_imports_are_public`](@ref)
* [`check_all_qualified_accesses_via_owners`](@ref)
* [`check_all_qualified_accesses_are_public`](@ref)
* [`check_no_self_qualified_accesses`](@ref)

The keyword argument `\$x` (e.g., `no_implicit_imports`) can be used to
control whether or not to run `check_\$x` (e.g., `check_no_implicit_imports`).
If `check_\$x` supports keyword arguments, a `NamedTuple` can also be
passed to `\$x` to specify the keyword arguments for `check_\$x`.

!!! note
    The function requires the stdlib Test to be loaded (e.g. `using Test`).

# Keyword Arguments

- `no_implicit_imports=true`
- `no_stale_explicit_imports=true`
- `all_explicit_imports_via_owners=true`
- `all_explicit_imports_are_public=true`
- `all_qualified_accesses_via_owners=true`
- `all_qualified_accesses_are_public=true`
- `no_self_qualified_accesses=true`
"""
function test_explicit_imports(package::Module, file=pathof(package);
                                no_implicit_imports=true,
                                no_stale_explicit_imports=true,
                                all_explicit_imports_via_owners=true,
                                all_explicit_imports_are_public=true,
                                all_qualified_accesses_via_owners=true,
                                all_qualified_accesses_are_public=true,
                                no_self_qualified_accesses=true)
    check_file(file)
    file_analysis = Dict{String,FileAnalysis}()

    @testset "ExplicitImports" begin
        if no_implicit_imports !== false
            test_no_implicit_imports(package, file;
                                     file_analysis,
                                     askwargs(no_implicit_imports)...)
        end

        if no_stale_explicit_imports !== false
            test_no_stale_explicit_imports(package, file;
                                           file_analysis,
                                           askwargs(no_stale_explicit_imports)...)
        end

        if all_explicit_imports_via_owners !== false
            test_all_explicit_imports_via_owners(package, file;
                                                 file_analysis,
                                                 askwargs(all_explicit_imports_via_owners)...)
        end

        if all_explicit_imports_are_public !== false
            test_all_explicit_imports_are_public(package, file;
                                                 file_analysis,
                                                 askwargs(all_explicit_imports_are_public)...)
        end

        if all_qualified_accesses_via_owners !== false
            test_all_qualified_accesses_via_owners(package, file;
                                                   file_analysis,
                                                   askwargs(all_qualified_accesses_via_owners)...)
        end

        if all_qualified_accesses_are_public !== false
            test_all_qualified_accesses_are_public(package, file;
                                                   file_analysis,
                                                   askwargs(all_qualified_accesses_are_public)...)
        end

        if no_self_qualified_accesses !== false
            test_no_self_qualified_accesses(package, file;
                                            file_analysis,
                                            askwargs(no_self_qualified_accesses)...)
        end
    end
end
