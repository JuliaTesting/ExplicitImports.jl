# Tests for default parameter value scoping
#= Run directly with:
julia --project -e '
    using TestEnv; TestEnv.activate()
    using ExplicitImports
    using ExplicitImports: get_names_used, is_in_default_parameter_value, descends_from_first_child_of
    using Test
    using DataFrames
    include("test/test_default_params.jl")'

Or run all tests with `Pkg.test()`.
=#

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

    # Case 11: Default value should see outer local scope
    @testset "Case 11: outer local in default value" begin
        @test check_no_stale_explicit_imports(TestModDefault11, TEST_FILE) === nothing
        usages = get_usages(:local_ref, [:TestModDefault11])
        @test any(row -> row.analysis_code == ExplicitImports.InternalAssignment, eachrow(usages))
        @test all(row -> row.analysis_code != ExplicitImports.External, eachrow(usages))
    end

    # Case 12: Arrow body tuple should not be treated as default params
    @testset "Case 12: arrow body tuple" begin
        usages = get_usages(:x, [:TestModDefault12])
        @test any(row -> row.analysis_code == ExplicitImports.InternalFunctionArg, eachrow(usages))
        @test all(row -> row.analysis_code != ExplicitImports.External, eachrow(usages))
    end

    # Case 13: Prior positional argument used in default
    @testset "Case 13: prior positional in default" begin
        @test check_no_stale_explicit_imports(TestModDefault13, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault13])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test all(row -> row.analysis_code != ExplicitImports.External,
                  eachrow(nonarg)) # default should see prior positional
    end

    # Case 14: Current parameter not visible in its own default
    @testset "Case 14: current param not visible" begin
        @test check_no_stale_explicit_imports(TestModDefault14, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault14])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(nonarg))
    end

    # Case 15: Later positional parameter not visible in earlier default
    @testset "Case 15: later positional not visible" begin
        @test check_no_stale_explicit_imports(TestModDefault15, TEST_FILE) === nothing
        usages = get_usages(:y, [:TestModDefault15])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(nonarg))
    end

    # Case 16: Keyword default can see positional parameter
    @testset "Case 16: keyword sees positional" begin
        @test check_no_stale_explicit_imports(TestModDefault16, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault16])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test all(row -> row.analysis_code != ExplicitImports.External,
                  eachrow(nonarg)) # keyword default should see positional
    end

    # Case 17: Keyword default can see earlier keyword
    @testset "Case 17: keyword sees earlier keyword" begin
        @test check_no_stale_explicit_imports(TestModDefault17, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault17])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test all(row -> row.analysis_code != ExplicitImports.External,
                  eachrow(nonarg)) # keyword default should see earlier keyword
    end

    # Case 18: Keyword default cannot see later keyword
    @testset "Case 18: keyword cannot see later keyword" begin
        @test check_no_stale_explicit_imports(TestModDefault18, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault18])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(nonarg))
    end

    # Case 19: Positional default cannot see keyword
    @testset "Case 19: positional cannot see keyword" begin
        @test check_no_stale_explicit_imports(TestModDefault19, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault19])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(nonarg))
    end

    # Case 20: Destructured positional bindings not visible in positional default
    @testset "Case 20: destructured positional not visible" begin
        @test check_no_stale_explicit_imports(TestModDefault20, TEST_FILE) === nothing
        usages = get_usages(:a, [:TestModDefault20])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(nonarg))
    end

    # Case 21: Destructured positional bindings not visible in keyword default
    @testset "Case 21: destructured positional not visible for keyword" begin
        @test check_no_stale_explicit_imports(TestModDefault21, TEST_FILE) === nothing
        usages = get_usages(:a, [:TestModDefault21])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(nonarg))
    end

    # Case 22: Typed prior positional parameter visible in later default
    @testset "Case 22: typed prior positional visible" begin
        @test check_no_stale_explicit_imports(TestModDefault22, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault22])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test all(row -> row.analysis_code != ExplicitImports.External,
                  eachrow(nonarg)) # typed prior positional should be visible
    end

    # Case 23: Nested function literal inside default sees prior parameter
    @testset "Case 23: nested function literal in default" begin
        @test check_no_stale_explicit_imports(TestModDefault23, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault23])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test all(row -> row.analysis_code != ExplicitImports.External,
                  eachrow(nonarg)) # nested literal should inherit default scope
    end

    # Case 24: Varargs positional binding visible to keyword default
    @testset "Case 24: varargs visible to keyword default" begin
        @test check_no_stale_explicit_imports(TestModDefault24, TEST_FILE) === nothing
        usages = get_usages(:x, [:TestModDefault24])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
        @test all(row -> row.analysis_code != ExplicitImports.External,
                  eachrow(nonarg)) # keyword default should see varargs
    end

    # Case 25: where-wrapped default param shadowing import
    @testset "Case 25: where-wrapped default param" begin
    @test check_no_stale_explicit_imports(TestModDefault25, TEST_FILE) === nothing
        usages = get_usages(:wrap_string, [:TestModDefault25])
        nonarg = subset(usages, :function_arg => ByRow(!))
        @test nrow(nonarg) >= 1
    @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(nonarg))
    end

    # Case 26: Arrow function assignment should not leak to outer scope
    @testset "Case 26: arrow scope boundary" begin
        usages = get_usages(:y, [:TestModDefault26])
        @test any(row -> row.analysis_code == ExplicitImports.External, eachrow(usages))
        @test any(row -> row.analysis_code == ExplicitImports.InternalAssignment,
                  eachrow(usages))
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

    @testset "Issue 98: kwarg name alone is stale" begin
        @test_throws ExplicitImports.StaleImportsException check_no_stale_explicit_imports(TestModIssue98KwargOnly,
                                                                                           TEST_FILE)
        usages = get_usages(:getindex, [:TestModIssue98KwargOnly])
        external_usages = subset(usages, :analysis_code => ByRow(==(ExplicitImports.External)))
        @test nrow(external_usages) == 0
        @test all(row -> row.analysis_code == ExplicitImports.IgnoredKwargName, eachrow(usages))
    end

    @testset "Issue 98: kwarg shorthand uses value" begin
        @test check_no_stale_explicit_imports(TestModIssue98Shorthand, TEST_FILE) === nothing
        usages = get_usages(:getindex, [:TestModIssue98Shorthand])
        external_usages = subset(usages, :analysis_code => ByRow(==(ExplicitImports.External)))
        @test nrow(external_usages) == 2
        @test nrow(usages) == 2
    end
end
