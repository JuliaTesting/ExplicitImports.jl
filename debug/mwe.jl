using Oceananigans, ExplicitImports, DataFrames
using ExplicitImports: get_names_used
# print_explicit_imports(Oceananigans.Fields)

# explicit_imports_nonrecursive(Oceananigans.Fields)

df = DataFrame(get_names_used("/Users/eph/.julia/packages/Oceananigans/HDYmM/src/Fields/field.jl").per_usage_info)
subset!(df, :name => ByRow(==(:I)))
select!(df, :location, :analysis_code)
show(df; allrows=true, allcols=true, truncate=10000)
