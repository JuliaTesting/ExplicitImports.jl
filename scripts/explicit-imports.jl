#!/usr/bin/env julia
@show Base.active_project()
@show ARGS
using ExplicitImports: main

exit(main(ARGS))
