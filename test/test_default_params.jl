# Test default parameter value scoping (issues #120, #62, #98)
# Included from runtests.jl

# Include the test modules
include("default_param_test_mods.jl")

const TEST_FILE = joinpath(@__DIR__, "default_param_test_mods.jl")

# Helper to get usages of a name in a module (excluding import statements)
function get_usages(name, mod_path)
    df = DataFrame(get_names_used(TEST_FILE).per_usage_info)
    subset(df,
           :name => ByRow(==(name)),
           :module_path => ByRow(==(mod_path)),
           :import_type => ByRow(!=(:import_RHS)))
end

@testset "Default parameter value scoping" begin
    # Original issue #120
    @testset "TestModIssue120 - original issue" begin
        @test check_no_stale_explicit_imports(TestModIssue120, TEST_FILE) === nothing

        df = DataFrame(get_names_used(TEST_FILE).per_usage_info)
        subset!(df, :name => ByRow(==(:wrap_string)), :module_path => ByRow(==([:TestModIssue120])))

        wrap_string_in_default = only(subset(df,
                                             :function_arg => ByRow(!),
                                             :import_type => ByRow(!=(:import_RHS)),
                                             :analysis_code => ByRow(==(ExplicitImports.External))))
        @test wrap_string_in_default.external_global_name === true
    end

    # Case 1: Type annotation on parameter - RefValue should NOT be flagged as stale
    @testset "Case 1: type annotation not in default value" begin
        @test check_no_stale_explicit_imports(TestModDefault1, TEST_FILE) === nothing
        usages = get_usages(:RefValue, [:TestModDefault1])
        @test nrow(usages) == 1
        @test only(usages).analysis_code == ExplicitImports.External
    end

    # Case 2: Same name in type annotation AND default value
    @testset "Case 2: type annotation and default value" begin
        @test check_no_stale_explicit_imports(TestModDefault2, TEST_FILE) === nothing
        usages = get_usages(:RefValue, [:TestModDefault2])
        @test nrow(usages) == 2
        @test all(row -> row.analysis_code == ExplicitImports.External, eachrow(usages))
    end

    # Case 3: Arrow function with default parameter
    @testset "Case 3: arrow function default" begin
        @test check_no_stale_explicit_imports(TestModDefault3, TEST_FILE) === nothing
        usages = get_usages(:wrap_string, [:TestModDefault3])
        external_usages = subset(usages, :analysis_code => ByRow(==(ExplicitImports.External)))
        @test nrow(external_usages) >= 1
    end

    # Case 4: Keyword argument with default value
    @testset "Case 4: keyword argument default" begin
        @test check_no_stale_explicit_imports(TestModDefault4, TEST_FILE) === nothing
        usages = get_usages(:wrap_string, [:TestModDefault4])
        external_usages = subset(usages, :analysis_code => ByRow(==(ExplicitImports.External)))
        @test nrow(external_usages) >= 1
    end

    # Case 5: Multiple parameters with defaults
    @testset "Case 5: multiple parameters" begin
        @test check_no_stale_explicit_imports(TestModDefault5, TEST_FILE) === nothing
        ws_usages = get_usages(:wrap_string, [:TestModDefault5])
        rv_usages = get_usages(:RefValue, [:TestModDefault5])
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(ws_usages))
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(rv_usages))
    end

    # Case 6: Nested function call in default value
    @testset "Case 6: nested default value" begin
        @test check_no_stale_explicit_imports(TestModDefault6, TEST_FILE) === nothing
        usages = get_usages(:wrap_string, [:TestModDefault6])
        external_usages = subset(usages, :analysis_code => ByRow(==(ExplicitImports.External)))
        @test nrow(external_usages) >= 1
    end

    # Case 7: Parametric type in signature
    @testset "Case 7: parametric type annotation" begin
        @test check_no_stale_explicit_imports(TestModDefault7, TEST_FILE) === nothing
        usages = get_usages(:RefValue, [:TestModDefault7])
        @test nrow(usages) == 1
        @test only(usages).analysis_code == ExplicitImports.External
    end

    # Case 8: Typed keyword argument
    @testset "Case 8: typed keyword argument" begin
        @test check_no_stale_explicit_imports(TestModDefault8, TEST_FILE) === nothing
        usages = get_usages(:RefValue, [:TestModDefault8])
        @test nrow(usages) == 2
        @test all(row -> row.analysis_code == ExplicitImports.External, eachrow(usages))
    end

    # Case 9: Short form function
    @testset "Case 9: short form function" begin
        @test check_no_stale_explicit_imports(TestModDefault9, TEST_FILE) === nothing
        usages = get_usages(:wrap_string, [:TestModDefault9])
        external_usages = subset(usages, :analysis_code => ByRow(==(ExplicitImports.External)))
        @test nrow(external_usages) >= 1
    end

    # Case 10: Where clause with default value
    @testset "Case 10: where clause with default" begin
        @test check_no_stale_explicit_imports(TestModDefault10, TEST_FILE) === nothing
        usages = get_usages(:RefValue, [:TestModDefault10])
        external_usages = subset(usages, :analysis_code => ByRow(==(ExplicitImports.External)))
        @test nrow(external_usages) >= 1
    end

    # Issue #98: Named tuple / kwarg with same name as imported function
    # https://github.com/JuliaTesting/ExplicitImports.jl/issues/98
    @testset "Issue 98: named tuple/kwarg shadowing" begin
        @test check_no_stale_explicit_imports(TestModIssue98, TEST_FILE) === nothing
        usages = get_usages(:getindex, [:TestModIssue98])
        # Each of test, test2, test3 has a usage of getindex as kwarg name (not External)
        # and as function call (should be External)
        external_usages = subset(usages, :analysis_code => ByRow(==(ExplicitImports.External)))
        # At least 3 external usages (one for each test function)
        @test nrow(external_usages) >= 3
    end
end
