# Integration tests

These tests attempt to check:

- that we don't introduce bugs which affect projects which use ExplicitImports in their testing
- if we do introduce non-bug changes which cause their tests to fail, we can let them know

## To add a project

1. Add a new directory like [Oceananigans](./Oceananigans/) with a Project.toml and [check.jl](./Oceananigans/check.jl) script
2. Add the project to the `project` job matrix in `.github/workflows/integration.yml`

Locally, `runtest.jl` runs every subdirectory with a `check.jl` by default, or you can pass one or more project names to run a subset: 

```
julia --project=integration integration/runtest.jl Oceananigans
```

In CI, each project is listed in the `project` job matrix is run in a separate job for parallelization.

## Important note

The Project.toml should have strict compatibility bounds on the package in question (of the form `=X.Y.Z`) so that changes to the package do not cause the test to start failing. The Project.toml's compat and the `check.jl` script should be updated in tandem.
