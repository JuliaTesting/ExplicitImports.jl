# Internal details

## Implementation strategy

1. [DONE hackily] Figure out what names used in the module are being used to refer to bindings in global scope (as opposed to e.g. shadowing globals).
   - We do this by parsing the code (thanks to JuliaSyntax), then reimplementing scoping rules on top of the parse tree
   - This is finicky, but assuming scoping doesn't change, should be robust enough (once the long tail of edge cases are dealt with...)
     - Currently, I don't handle the `global` keyword, so those may look like local variables and confuse things
   - This means we need access to the raw source code; `pathof` works well for packages, but for local modules one has to pass the path themselves. Also doesn't seem to work well for stdlibs in the sysimage
2. [DONE] Figure out what implicit imports are available in the module, and which module they come from
    * done, via a magic `ccall` from Discourse, and `Base.which`.
3. [DONE] Figure out which names have been explicitly imported already
   - Done via parsing

Then we can put this information together to figure out what names are actually being used from other modules, and whose usage could be made explicit, and also which existing explicit imports are not being used.

## Internals

```@docs
ExplicitImports.find_implicit_imports
ExplicitImports.get_names_used
ExplicitImports.analyze_all_names
ExplicitImports.inspect_session
ExplicitImports.FileAnalysis
ExplicitImports.get_default_skip_pairs
```

## How to debug issues

There are 2 sources of data used by ExplicitImports:

- static: read the file, parse the code with JuliaSyntax, then do some ad-hoc lowering to identify scoping and which names are being used
   - the main function here is [`ExplicitImports.get_names_used`](@ref)
- dynamic: load the module, and get a list of names available in its namespace due to being exported by other modules
   - this is done dynamically since we don't look at source code outside of the current project. (Potentially we could parse them too and do everything statically?).
   - this lets the Julia runtime tell us which names are being implicitly imported
   - this is done via [`ExplicitImports.find_implicit_imports`](@ref)

We then reconcile these lists against each other to identify which implicit imports are used (and therefore could be converted into explicit imports), stale explicit imports, etc.

Most of the work here is done on the static side and most of the bugs are on the static side.

Let's say you think there is something going wrong there. The first step is to write a minimal reproducible example as a file, e.g. here `issue_129.jl`. Then we can learn what ExplicitImports thinks about every single identifier in the file via:

```julia
julia> using ExplicitImports, DataFrames, PrettyTables

julia> df = DataFrame(ExplicitImports.get_names_used("issue_129.jl").per_usage_info);

julia> select!(df, Not(:scope_path)); # too verbose

julia> open("table.md"; write=true) do io
       PrettyTables.pretty_table(io, df; show_subheader=false, tf=PrettyTables.tf_markdown)
       end
```

We can then use DataFrames manipulations to subset `df` to parts of interest etc. Usually we can then track down where a name has been misidentified and fix the relevant bit of code.
