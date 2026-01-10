issue_path = joinpath(@__DIR__, "issue_111.jl")
include(issue_path)

analysis = ExplicitImports.get_names_used(issue_path).per_usage_info

function hello_codes(modsym::Symbol)
    return Set(nt.analysis_code for nt in analysis
               if nt.name == :hello && nt.module_path == [modsym])
end

@testset "struct field name with inner constructor uses import" begin
    @test check_no_stale_explicit_imports(FieldNameInnerConstructor, issue_path) === nothing
    codes = hello_codes(:FieldNameInnerConstructor)
    @test ExplicitImports.InternalStruct in codes
    @test ExplicitImports.External in codes
end

@testset "mutable struct field name with inner constructor uses import" begin
    @test check_no_stale_explicit_imports(MutableFieldNameInnerConstructor, issue_path) ===
          nothing
    codes = hello_codes(:MutableFieldNameInnerConstructor)
    @test ExplicitImports.InternalStruct in codes
    @test ExplicitImports.External in codes
end

@testset "kwdef field default uses import" begin
    @test check_no_stale_explicit_imports(KwdefFieldDefault, issue_path) === nothing
    codes = hello_codes(:KwdefFieldDefault)
    @test ExplicitImports.InternalStruct in codes
    @test ExplicitImports.External in codes
end

@testset "field name alone is stale import" begin
    @test_throws ExplicitImports.StaleImportsException check_no_stale_explicit_imports(FieldNameOnly,
                                                                                       issue_path)
    codes = hello_codes(:FieldNameOnly)
    @test ExplicitImports.InternalStruct in codes
    @test ExplicitImports.External ∉ codes
end

@testset "untyped field name alone is stale import" begin
    @test_throws ExplicitImports.StaleImportsException check_no_stale_explicit_imports(UntypedFieldNameOnly,
                                                                                       issue_path)
    codes = hello_codes(:UntypedFieldNameOnly)
    @test ExplicitImports.InternalStruct in codes
    @test ExplicitImports.External ∉ codes
end
