issue_path = joinpath(@__DIR__, "issue_111.jl")
include(issue_path)

analysis = ExplicitImports.get_names_used(issue_path).per_usage_info

function hello_usages(modsym::Symbol)
    return filter(analysis) do nt
        nt.name == :hello && nt.module_path == [modsym]
    end
end

@testset "struct field name with inner constructor uses import" begin
    @test check_no_stale_explicit_imports(FieldNameInnerConstructor, issue_path) === nothing
    usages = hello_usages(:FieldNameInnerConstructor)
    @test getfield.(usages, :analysis_code) ==
          [ExplicitImports.IgnoredImportRHS,
           ExplicitImports.InternalStruct,
           ExplicitImports.External]
end

@testset "mutable struct field name with inner constructor uses import" begin
    @test check_no_stale_explicit_imports(MutableFieldNameInnerConstructor, issue_path) ===
          nothing
    usages = hello_usages(:MutableFieldNameInnerConstructor)
    @test getfield.(usages, :analysis_code) ==
          [ExplicitImports.IgnoredImportRHS,
           ExplicitImports.InternalStruct,
           ExplicitImports.External]
end

@testset "kwdef field default uses import" begin
    @test check_no_stale_explicit_imports(KwdefFieldDefault, issue_path) === nothing
    usages = hello_usages(:KwdefFieldDefault)
    @test getfield.(usages, :analysis_code) ==
          [ExplicitImports.IgnoredImportRHS,
           ExplicitImports.InternalStruct,
           ExplicitImports.External]
end

@testset "field name alone is stale import" begin
    @test_throws ExplicitImports.StaleImportsException check_no_stale_explicit_imports(FieldNameOnly,
                                                                                       issue_path)
    usages = hello_usages(:FieldNameOnly)
    @test getfield.(usages, :analysis_code) ==
          [ExplicitImports.IgnoredImportRHS,
           ExplicitImports.InternalStruct]
end

@testset "untyped field name alone is stale import" begin
    @test_throws ExplicitImports.StaleImportsException check_no_stale_explicit_imports(UntypedFieldNameOnly,
                                                                                       issue_path)
    usages = hello_usages(:UntypedFieldNameOnly)
    @test getfield.(usages, :analysis_code) ==
          [ExplicitImports.IgnoredImportRHS,
           ExplicitImports.InternalStruct]
end
