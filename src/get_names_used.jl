# In this file, we try to answer the question: what global bindings are being used in a particular module?
# We will do this by parsing, then re-implementing scoping rules on top of the parse tree.
# See `src/parse_utilities.jl` for an overview of the strategy and the utility functions we will use.

@enum AnalysisCode IgnoredNonFirst IgnoredQualified IgnoredImportRHS InternalHigherScope InternalFunctionArg InternalAssignment InternalStruct InternalForLoop InternalGenerator InternalCatchArgument External IgnoredKwargName

const RECURSION_LIMIT = 100

# Tracks default-expression scope metadata so name resolution can honor Julia's
# prior-parameter visibility rules without treating defaults as full function scope.
struct DefaultParamContext
    owner::JuliaSyntax.SyntaxNode
    visible_names::Vector{Symbol}
end

# Holds mutable traversal state while walking from a leaf to the root.
# Keeps scope and module paths together so scope logic stays localized.
mutable struct ScopeWalkState
    module_path::Vector{Symbol}
    scope_path::Vector{JuliaSyntax.SyntaxNode}
    is_assignment::Bool
    default_param_ctx::Union{Nothing,DefaultParamContext}
end

function ScopeWalkState(default_param_ctx::Union{Nothing,DefaultParamContext})
    return ScopeWalkState(Symbol[], JuliaSyntax.SyntaxNode[], false, default_param_ctx)
end

Base.@kwdef struct PerUsageInfo
    name::Symbol
    qualified_by::Union{Nothing,Vector{Symbol}}
    import_type::Symbol
    explicitly_imported_by::Union{Nothing,Vector{Symbol}}
    location::String
    function_arg::Bool
    is_assignment::Bool
    module_path::Vector{Symbol}
    scope_path::Vector{JuliaSyntax.SyntaxNode}
    struct_field_name::Bool
    kwarg_name::Bool
    struct_field_or_type_param::Bool
    for_loop_index::Bool
    generator_index::Bool
    catch_arg::Bool
    default_param_ctx::Union{Nothing,DefaultParamContext} = nothing
    first_usage_in_scope::Bool
    external_global_name::Union{Missing,Bool}
    analysis_code::AnalysisCode
end

function Base.show(io::IO, r::PerUsageInfo)
    return print(io,
                 "PerUsageInfo (`$(r.name)` @ $(r.location), `qualified_by`=$(r.qualified_by))")
end

function Base.NamedTuple(r::PerUsageInfo)
    names = fieldnames(typeof(r))
    return NamedTuple{names}(map(x -> getfield(r, x), names))
end

"""
    FileAnalysis

Contains structured analysis results.

## Fields

-  per_usage_info::Vector{PerUsageInfo}
- `needs_explicit_import::Set{@NamedTuple{name::Symbol,module_path::Vector{Symbol},
    location::String}}`
- `unnecessary_explicit_import::Set{@NamedTuple{name::Symbol,module_path::Vector{Symbol},
          location::String}}`
- `untainted_modules::Set{Vector{Symbol}}`: those which were analyzed and do not contain an unanalyzable `include`
"""
Base.@kwdef struct FileAnalysis
    per_usage_info::Vector{PerUsageInfo}
    needs_explicit_import::Set{@NamedTuple{name::Symbol,module_path::Vector{Symbol},
                                           location::String}}
    unnecessary_explicit_import::Set{@NamedTuple{name::Symbol,module_path::Vector{Symbol},
                                                 location::String}}
    untainted_modules::Set{Vector{Symbol}}
end

# returns `nothing` for no qualifying module, otherwise a symbol
function qualifying_module(leaf)
    @debug "[qualifying_module] leaf: $(js_node(leaf)) start"
    # introspect leaf and its tree of parents
    @debug "[qualifying_module] leaf: $(js_node(leaf)) parents: $(parent_kinds(leaf))"

    # is this name being used in a qualified context, like `X.y`?
    parents_match(leaf, (K".",)) || return nothing
    @debug "[qualifying_module] leaf: $(js_node(leaf)) passed dot"
    # Are we on the right-hand side?
    child_index(leaf) == 2 || return nothing
    @debug "[qualifying_module] leaf: $(js_node(leaf)) passed right-hand side"
    # Ok, now try to retrieve the child on the left-side
    node = first(AbstractTrees.children(parent(leaf)))
    path = Symbol[]
    retrieve_module_path!(path, node)
    return path
end

function retrieve_module_path!(path, node)
    kids = AbstractTrees.children(node)
    if kind(node) == K"Identifier"
        push!(path, get_val(node))
    elseif kind(node) == K"."
        k1, k2 = kids
        if kind(k1) === K"Identifier"
            push!(path, get_val(k1))
        end
        return retrieve_module_path!(path, k2)
    elseif kind(node) == K"quote"
        return retrieve_module_path!(path, first(kids))
    end
    return path
end

# figure out if `leaf` is part of an import or using statement
# this seems to trigger for both `X` and `y` in `using X: y`, but that seems alright.
function analyze_import_type(leaf)
    kind(leaf) in (K"Identifier", K"MacroName", K"StringMacroName") || return :not_import
    has_parent(leaf) || return :not_import
    is_import = parents_match(leaf, (K"importpath",))
    is_import || return :not_import
    if parents_match(leaf, (K"importpath", K":"))
        # we are on the LHS if we are the first child
        if child_index(parent(leaf)) == 1
            return :import_LHS
        else
            return :import_RHS
        end
    elseif parents_match(leaf, (K"importpath", K"as", K":"))
        # this name is either part of an `import X: a as b` statement
        # since we are in an `importpath`, we are the `a` part, not the `b` part, I think
        # do we also want to identify the `b` part as an `import_RHS`?
        # For the purposes of stale explicit imports, we want to know about `b`,
        # since if `b` is unused then it is stale.
        # For the purposes of not suggesting an explicit import that already exists,
        # it is weird since they have renamed it here, so if they are referring to
        # both names in their code (`a` and `b`), that's kind of a different confusing
        # issue.
        # For the purposes of "are they importing a non-public name", we care more about
        # `a`, since that's the name we need to check if it is public or not in the source
        # module (although we could check if `b` is public in the module sourced via `which`?).
        # hm..
        # let's just leave it; for now `b` will be declared `:not_import`
        return :import_RHS
    else
        # Not part of `:` generally means it's a `using X` or `import Y` situation
        # We could be using X.Y.Z, so we will return `plain_import` or `plain_import_member` depending if we are the last one or not
        n_children = length(js_children(parent(leaf)))
        last_child = child_index(leaf) == n_children
        if parents_match(leaf, (K"importpath", K"using"))
            return last_child ? :plain_import : :plain_import_member
        elseif parents_match(leaf, (K"importpath", K"import"))
            return last_child ? :blanket_using : :blanket_using_member
        elseif parents_match(leaf, (K"importpath", K"as", K"import"))
            # import X as Y
            # Here we are `X`, not `Y`
            return last_child ? :plain_import : :plain_import_member
        else
            error("Unhandled case $(js_node(get_parent(leaf, 3)))")
        end
    end
end

function is_function_definition_arg(leaf)
    return is_anonymous_function_definition_arg(leaf) ||
           is_non_anonymous_function_definition_arg(leaf) ||
           is_anonymous_do_function_definition_arg(leaf)
end

function is_anonymous_do_function_definition_arg(leaf)
    if !has_parent(leaf, 2)
        return false
    elseif parents_match(leaf, (K"tuple", K"do"))
        # first argument of `do`-block (args then function body since JuliaSyntax 1.0)
        return child_index(parent(leaf)) == 1
    elseif kind(parent(leaf)) in (K"tuple", K"parameters")
        # Ok, let's just step up one level and see again
        return is_anonymous_do_function_definition_arg(parent(leaf))
    else
        return false
    end
end

function is_anonymous_function_definition_arg(leaf)
    if parents_match(leaf, (K"->",))
        # lhs of a `->`
        return child_index(leaf) == 1
    elseif parents_match(leaf, (K"tuple", K"->"))
        # lhs of a multi-argument `->`
        return child_index(parent(leaf)) == 1
    elseif parents_match(leaf, (K"parameters", K"tuple", K"->"))
        return child_index(get_parent(leaf, 2)) == 1
    elseif parents_match(leaf, (K"function", K"="))
        # `function` is RHS of `=`
        return child_index(parent(leaf)) == 2
    elseif parents_match(leaf, (K"tuple", K"function", K"="))
        # `function` is RHS of `=`
        return child_index(get_parent(leaf, 2)) == 2
    elseif parents_match(leaf, (K"parameters", K"tuple", K"function", K"="))
        # `function` is RHS of `=`
        return child_index(get_parent(leaf, 3)) == 2
    elseif parents_match(leaf, (K"::",))
        # we must be on the LHS, otherwise we're a type
        is_double_colon_LHS(leaf) || return false
        # Ok, let's just step up one level and see again
        return is_anonymous_function_definition_arg(parent(leaf))
    elseif parents_match(leaf, (K"=",))
        # we must be on the LHS, otherwise we're a default value
        child_index(leaf) == 1 || return false
        # Ok, let's just step up one level and see again
        return is_anonymous_function_definition_arg(parent(leaf))
    else
        return false
    end
end

# check if `leaf` is a function argument (or kwarg), but not a default value etc,
# which is part of a function definition (not just any function call)
function is_non_anonymous_function_definition_arg(leaf)
    if parents_match(leaf, (K"call",)) && call_is_func_def(parent(leaf))
        # We are a function arg if we're a child of `call` who is not the function name itself
        return child_index(leaf) != 1
    elseif parents_match(leaf, (K"parameters", K"call")) &&
           call_is_func_def(get_parent(leaf, 2))
        # we're a kwarg without default value in a call
        return true
    elseif parents_match(leaf, (K"=",))
        # we must be on the LHS, otherwise we aren't a function arg
        child_index(leaf) == 1 || return false
        # Ok, let's just step up one level and see again
        return is_non_anonymous_function_definition_arg(parent(leaf))
    elseif parents_match(leaf, (K"::",))
        # we must be on the LHS, otherwise we're a type
        is_double_colon_LHS(leaf) || return false
        # Ok, let's just step up one level and see again
        return is_non_anonymous_function_definition_arg(parent(leaf))
    elseif parents_match(leaf, (K"...",))
        # Handle varargs like `foo(args...)` - step up one level
        return is_non_anonymous_function_definition_arg(parent(leaf))
    else
        return false
    end
end

function get_import_lhs(import_rhs_leaf)
    if parents_match(import_rhs_leaf, (K"importpath", K":"))
        n = first(children(get_parent(import_rhs_leaf, 2)))
        @assert kind(n) == K"importpath"
        return filter!(!isnothing, get_val.(children(n)))
    elseif parents_match(import_rhs_leaf, (K"importpath", K"as", K":"))
        n = first(children(get_parent(import_rhs_leaf, 3)))
        @assert kind(n) == K"importpath"
        return filter!(!isnothing, get_val.(children(n)))
    else
        error("does not seem to be an import RHS")
    end
end

# given a `call`-kind node, is it a function invocation or a function definition?
function call_is_func_def(node)
    kind(node) == K"call" || error("Not a call")
    p = parent(node)
    p === nothing && return false
    # note: macros only support full-form function definitions
    # (not inline)
    # must be first child of function/macro to qualify
    kind(p) in (K"function", K"macro") && child_index(node) == 1 && return true
    return false
end

function is_struct_field_name(leaf)
    kind(leaf) == K"Identifier" || return false
    if parents_match(leaf, (K"::", K"block", K"struct"))
        # we want to be on the LHS of the `::`
        return is_double_colon_LHS(leaf)
    elseif parents_match(leaf, (K"::", K"=", K"block", K"struct"))
        # if we are in a `Base.@kwdef`, we may be on the LHS of an `=`
        return is_double_colon_LHS(leaf) && child_index(parent(leaf)) == 1
    elseif parents_match(leaf, (K"=", K"block", K"struct"))
        # untyped field with default value (`x = 1`) inside the struct block
        return child_index(leaf) == 1
    elseif parents_match(leaf, (K"block", K"struct"))
        # untyped field declaration (`x`) inside the struct block
        return true
    else
        return false
    end
end

function is_struct_type_param(leaf)
    kind(leaf) == K"Identifier" || return false
    if parents_match(leaf, (K"curly", K"struct"))
        # Here we want the non-first argument of `curly`
        return child_index(leaf) > 1
    elseif parents_match(leaf, (K"curly", K"<:", K"struct"))
        # Handle `struct Foo{T} <: Bar` - type params in curly inside <: inside struct
        return child_index(leaf) > 1 && child_index(get_parent(leaf)) == 1
    elseif parents_match(leaf, (K"<:", K"curly", K"struct"))
        # Here we only want the LHS of the <:, AND the not-first argument of curly
        return child_index(leaf) == 1 && child_index(get_parent(leaf)) > 1
    elseif parents_match(leaf, (K"<:", K"curly", K"<:", K"struct"))
        # Handle `struct Foo{T <: Number} <: Bar` - type param with bound in curly inside <: inside struct
        return child_index(leaf) == 1 && child_index(get_parent(leaf)) > 1 && child_index(get_parent(leaf, 2)) == 1
    else
        return false
    end
end

# Check if an identifier is a keyword argument name or named tuple field name.
function is_kwarg_name(leaf)
    kind(leaf) == K"Identifier" || return false
    parents_match(leaf, (K"=",)) || return false
    child_index(leaf) == 1 || return false

    if parents_match(leaf, (K"=", K"parameters", K"call"))
        call_node = get_parent(leaf, 3)
        return function_def_scope_owner(call_node) === nothing
    elseif parents_match(leaf, (K"=", K"parameters", K"tuple"))
        return true
    elseif parents_match(leaf, (K"=", K"tuple"))
        return true
    end

    return false
end

# Check if an identifier is a type parameter being *defined* in a `where` clause.
# e.g., in `function foo(x::T) where T`, the second `T` is the definition.
# The `where` node has structure: (where <expr> <type_param1> <type_param2> ...)
# So type params are children with index > 1.
function is_where_type_param(leaf)
    kind(leaf) == K"Identifier" || return false
    if parents_match(leaf, (K"where",))
        # Type params are non-first children of `where`
        return child_index(leaf) > 1
    elseif parents_match(leaf, (K"<:", K"where"))
        # Handle `where T <: Number` - T is on LHS of <:
        return child_index(leaf) == 1 && child_index(get_parent(leaf)) > 1
    elseif parents_match(leaf, (K"curly", K"where"))
        # Handle `where {T, S}` syntax - type params inside curly braces
        return child_index(get_parent(leaf)) > 1
    elseif parents_match(leaf, (K"braces", K"where"))
        # Handle `where {T, S}` syntax - braces is used instead of curly
        return child_index(get_parent(leaf)) > 1
    elseif parents_match(leaf, (K"<:", K"curly", K"where"))
        # Handle `where {T <: Number, S}` syntax
        return child_index(leaf) == 1 && child_index(get_parent(leaf, 2)) > 1
    elseif parents_match(leaf, (K"<:", K"braces", K"where"))
        # Handle `where {T <: Number, S}` syntax with braces
        return child_index(leaf) == 1 && child_index(get_parent(leaf, 2)) > 1
    else
        return false
    end
end

# Get all type parameter names defined by a `where` clause.
# The `where` node has structure: (where <expr> <type_param1> <type_param2> ...)
function get_where_type_params(where_node)
    names = Symbol[]
    kids = js_children(where_node)
    for (i, child) in enumerate(kids)
        i == 1 && continue  # Skip the first child (the expression)
        _collect_type_param_names!(names, child)
    end
    return names
end

function _collect_type_param_names!(names, node)
    k = kind(node)
    if k == K"Identifier"
        push!(names, get_val(node))
    elseif k == K"<:"
        # For `T <: Number`, we want `T` which is the first child
        kids = js_children(node)
        if !isempty(kids)
            _collect_type_param_names!(names, first(kids))
        end
    elseif k in (K"curly", K"braces")
        # For `where {T, S}`, collect all identifiers
        # Note: `where {T, S}` uses `braces`, while `Foo{T, S}` uses `curly`
        for child in js_children(node)
            _collect_type_param_names!(names, child)
        end
    end
end

# Check if an identifier is *used* inside a `where` clause and is bound by
# one of the type parameters defined in that (or an enclosing) `where` clause.
# e.g., in `function foo(x::T) where T`, the first `T` (in `x::T`) is bound by the `where`.
function is_bound_by_where_clause(leaf)
    kind(leaf) == K"Identifier" || return false
    name = get_val(leaf)
    # Walk up the tree looking for `where` clauses
    node = leaf
    while has_parent(node)
        p = parent(node)
        if kind(p) == K"where"
            # Check if we're in the first child (the expression where type params are used)
            # and if our name is one of the type params
            if child_index(node) == 1
                type_params = get_where_type_params(js_node(p))
                if name in type_params
                    return true
                end
            end
            # Also check enclosing `where` clauses (for nested `where` like `where T where S`)
        end
        node = p
    end
    return false
end

# In the future, this may need an update for
# https://github.com/JuliaLang/JuliaSyntax.jl/issues/432
function in_for_argument_position(node)
    # We must be on the LHS of a `for` `equal`.
    if !has_parent(node, 3)
        return false
    elseif parents_match(node, (K"in", K"iteration", K"for"))
        @debug """
        [in_for_argument_position] node: $(js_node(node))
        parents: $(parent_kinds(node))
        child_index=$(child_index(node))
        parent_child_index=$(child_index(get_parent(node, 1)))
        parent_child_index2=$(child_index(get_parent(node, 2)))
        """

        # child_index(node) == 1 means we are the first argument of the `in`, like `yi in y`
        return child_index(node) == 1
    elseif kind(parent(node)) in (K"tuple", K"parameters")
        return in_for_argument_position(get_parent(node))
    else
        return false
    end
end

function is_for_arg(leaf)
    kind(leaf) == K"Identifier" || return false
    return in_for_argument_position(leaf)
end

function is_generator_arg(leaf)
    kind(leaf) == K"Identifier" || return false
    return in_generator_arg_position(leaf)
end

function in_generator_arg_position(node)
    # We must be on the LHS of a `=` inside a generator
    # (possibly inside a filter, possibly inside a `iteration`)
    if !has_parent(node, 3)
        return false
    elseif parents_match(node, (K"in", K"iteration", K"generator")) ||
           parents_match(node, (K"in", K"iteration", K"filter"))
        return child_index(node) == 1
    elseif kind(parent(node)) in (K"tuple", K"parameters")
        return in_generator_arg_position(get_parent(node))
    else
        return false
    end
end

function is_catch_arg(leaf)
    kind(leaf) == K"Identifier" || return false
    return in_catch_arg_position(leaf)
end

# Cache all leaf-specific facts up front so scope walking stays focused.
function collect_leaf_flags(leaf)
    struct_field_name = is_struct_field_name(leaf)
    kwarg_name = is_kwarg_name(leaf)
    return (;
            function_arg=is_function_definition_arg(leaf),
            struct_field_name,
            kwarg_name,
            struct_field_or_type_param=is_struct_type_param(leaf) || struct_field_name ||
                                       is_where_type_param(leaf) ||
                                       is_bound_by_where_clause(leaf),
            for_loop_index=is_for_arg(leaf),
            generator_index=is_generator_arg(leaf),
            catch_arg=is_catch_arg(leaf),
            default_param_ctx=default_param_context(leaf))
end

function in_catch_arg_position(node)
    # We must be the first argument of a `catch` block
    if !has_parent(node)
        return false
    elseif parents_match(node, (K"catch",))
        return child_index(node) == 1
    else
        # catch doesn't support destructuring, type annotations, etc, so we're done!
        return false
    end
end

# matches `x` in `x::Y`, but not `Y`, nor `foo(::Y)`
function is_double_colon_LHS(leaf)
    parents_match(leaf, (K"::",)) || return false
    unary = has_flags(get_parent(leaf), JuliaSyntax.PREFIX_OP_FLAG)
    unary && return false
    # OK if not unary, then check we're in position 1 for LHS
    return child_index(leaf) == 1
end

# Check if a leaf is within a default parameter value expression
# Default parameter values are evaluated in the outer scope, not the function's scope
function is_in_default_parameter_value(leaf; debug=false)
    return default_param_context(leaf; debug=debug) !== nothing
end

function simple_param_name(node)
    k = kind(node)
    if k == K"Identifier"
        return get_val(node)
    elseif k in (K"::", K"=", K"...")
        kids = js_children(node)
        isempty(kids) && return nothing
        return simple_param_name(first(kids))
    end
    return nothing
end

# Collect prior positional parameter names that are simple identifiers.
function prior_positional_param_names(call_node, stop_idx)
    visible = Symbol[]
    kids = js_children(call_node)
    for i in 2:(stop_idx - 1)
        name = simple_param_name(kids[i])
        name === nothing || push!(visible, name)
    end
    return visible
end

# Collect prior arrow-function tuple parameter names.
function prior_tuple_param_names(tuple_node, stop_idx)
    visible = Symbol[]
    kids = js_children(tuple_node)
    for i in 1:(stop_idx - 1)
        name = simple_param_name(kids[i])
        name === nothing || push!(visible, name)
    end
    return visible
end

# Collect positional + prior keyword parameter names for keyword defaults.
function prior_keyword_param_names(call_node, params_node, stop_idx)
    visible = Symbol[]
    for (i, child) in enumerate(js_children(call_node))
        i == 1 && continue
        child === js_node(params_node) && break
        name = simple_param_name(child)
        name === nothing || push!(visible, name)
    end
    kids = js_children(params_node)
    for i in 1:(stop_idx - 1)
        name = simple_param_name(kids[i])
        name === nothing || push!(visible, name)
    end
    return visible
end

function push_scope_if_needed!(state, node, idx)
    k = kind(node)
    args = nodevalue(node).node.raw.children
    if k in
       (K"let", K"for", K"function", K"struct", K"generator", K"while", K"macro", K"do", K"->") ||
       # any child of `try` gets it's own individual scope (I think)
       (parents_match(node, (K"try",)))
        # Skip the function scope that owns a default value (default values are in the outer scope).
        if state.default_param_ctx === nothing ||
           nodevalue(node).node !== state.default_param_ctx.owner
            push!(state.scope_path, nodevalue(node).node)
        end
    elseif idx > 3 && k == K"=" && !isempty(args) &&
           kind(first(args)) == K"call"
        # Skip inline function scope when analyzing its default values.
        if state.default_param_ctx === nothing ||
           nodevalue(node).node !== state.default_param_ctx.owner
            push!(state.scope_path, nodevalue(node).node)
        end
    end
end

function track_module_path!(state, node)
    kind(node) == K"module" || return
    ids = filter(children(nodevalue(node))) do arg
        return kind(arg.node) == K"Identifier"
    end
    if !isempty(ids)
        push!(state.module_path, first(ids).node.val)
    end
    push!(state.scope_path, nodevalue(node).node)
end

function track_assignment_lhs!(state, node, leaf)
    kind(node) == K"=" || return
    kids = children(nodevalue(node))
    if !isempty(kids)
        c = first(kids)
        state.is_assignment |= c == nodevalue(leaf)
    end
end

# Return the default-parameter evaluation context if `leaf` is inside a default value.
# Walk up ancestors to detect a default expression and its visible prior params.
function default_param_context(leaf; debug=false)
    node = leaf
    # Walk up the tree looking for a `=` node that's part of a function parameter
    for i in 1:RECURSION_LIMIT  # limit depth to avoid infinite loops
        has_parent(node) || return nothing
        node = parent(node)
        k = kind(node)

        debug && println("  Step $i: kind = $k")

        # If we found a `=` node, check if it's a default parameter
        if k == K"="
            ctx = default_param_context_for_eq(leaf, node; debug=debug)
            ctx === nothing || return ctx
        end

        if i == RECURSION_LIMIT
            @warn "default_param_context reached recursion limit" leaf
        end
    end
    return nothing
end

function default_param_context_for_eq(leaf, eq_node; debug=false)
    # Make sure the original leaf is on the RHS of the `=` (the default value)
    descends_from_first_child_of(leaf, eq_node) && return nothing

    # Regular function with default: f(x = default)
    if parents_match(eq_node, (K"call",))
        call_node = parent(eq_node)
        owner = function_def_scope_owner(call_node)
        if owner !== nothing
            debug && println("  -> Matched regular function default")
            visible = prior_positional_param_names(call_node, child_index(eq_node))
            return DefaultParamContext(owner, visible)
        end
    elseif parents_match(eq_node, (K"tuple",))
        # Arrow function with default: (x = default) -> body
        # The tuple should be the first child of ->
        tuple_node = parent(eq_node)
        debug && println("  -> Matched tuple parent, checking for ->")
        debug && println("     has_parent(tuple_node) = $(has_parent(tuple_node))")
        if has_parent(tuple_node)
            debug && println("     kind(parent(tuple_node)) = $(kind(parent(tuple_node)))")
        end
        if has_parent(tuple_node) && kind(parent(tuple_node)) == K"->" &&
           child_index(tuple_node) == 1
            debug && println("  -> Matched arrow function default")
            visible = prior_tuple_param_names(tuple_node, child_index(eq_node))
            return DefaultParamContext(nodevalue(parent(tuple_node)).node, visible)
        end
    elseif parents_match(eq_node, (K"parameters",))
        # Keyword argument with default: f(; x = default) or f(a; x = default)
        # Structure: = -> parameters -> call -> function
        parent_node = parent(eq_node)  # parameters
        if has_parent(parent_node)
            call_node = parent(parent_node)  # call
            owner = function_def_scope_owner(call_node)
            if owner !== nothing
                debug && println("  -> Matched keyword argument default")
                visible = prior_keyword_param_names(call_node, parent_node, child_index(eq_node))
                return DefaultParamContext(owner, visible)
            end
        end
    end

    return nothing
end

function function_def_scope_owner(call_node)
    kind(call_node) == K"call" || return nothing
    if call_is_func_def(call_node)
        return nodevalue(parent(call_node)).node
    end
    has_parent(call_node) || return nothing
    parent_node = parent(call_node)
    if kind(parent_node) == K"=" && child_index(call_node) == 1
        return nodevalue(parent_node).node
    end
    return nothing
end

# Helper: check if `descendent` is a descendent of the first child of `ancestor`
function descends_from_first_child_of(descendent, ancestor)
    kids = children(nodevalue(ancestor))
    isempty(kids) && return false
    first_child = first(kids).node

    # Check if descendent is the first child or a descendent of it
    # Walk up the tree from descendent; if we hit first_child before ancestor, return true
    node = descendent
    for i in 1:RECURSION_LIMIT  # safety limit to avoid infinite loops
        if nodevalue(node).node === first_child
            return true
        end
        has_parent(node) || return false
        parent_node = parent(node)
        # If parent is the first_child, then descendent is inside first_child's subtree
        if nodevalue(parent_node).node === first_child
            return true
        end
        # If we reached the ancestor without going through first_child, descendent is not in first_child's subtree
        if nodevalue(parent_node).node === nodevalue(ancestor).node
            return false
        end
        node = parent_node

        if i == RECURSION_LIMIT
            @warn "descends_from_first_child_of reached recursion limit" descendent ancestor
        end
    end
    return false
end

# Here we use the magic of AbstractTrees' `TreeCursor` so we can start at
# a leaf and follow the parents up to see what scopes our leaf is in.
# TODO-someday- cleanup. This basically has two jobs: check is function arg etc, and figure out the scope/module path.
# We could do these two things separately for more clarity.
function analyze_name(leaf; debug=false)
    # Ok, we have a "name". Let us work our way up and try to figure out if it is in local scope or not
    leaf_flags = collect_leaf_flags(leaf)
    state = ScopeWalkState(leaf_flags.default_param_ctx)
    node = leaf
    idx = 1

    while true
        # update our state
        val = get_val(node)
        k = kind(node)

        debug && println(val, ": ", k)
        # Constructs that start a new local scope. Note `let` & `macro` *arguments* are not explicitly supported/tested yet,
        # but we can at least keep track of scope properly.
        push_scope_if_needed!(state, node, idx)

        # track which modules we are in
        track_module_path!(state, node)

        # figure out if our name (`nodevalue(leaf)`) is the LHS of an assignment
        # Note: this doesn't detect assignments to qualified variables (`X.y = rhs`)
        # but that's OK since we don't want to pick them up anyway.
        track_assignment_lhs!(state, node, leaf)

        node = parent(node)

        # finished climbing to the root
        node === nothing &&
            return (; leaf_flags.function_arg,
                    is_assignment=state.is_assignment,
                    module_path=state.module_path,
                    scope_path=state.scope_path,
                    leaf_flags.struct_field_name,
                    leaf_flags.kwarg_name,
                    leaf_flags.struct_field_or_type_param,
                    leaf_flags.for_loop_index,
                    leaf_flags.generator_index,
                    leaf_flags.catch_arg,
                    leaf_flags.default_param_ctx)
        idx += 1
    end
end

function cmdstring_parent(leaf)
    node = leaf
    while true
        kind(node) == K"cmdstring" && return node
        has_parent(node) || return nothing
        node = parent(node)
    end
end

function unwrap_toplevel_expr(expr)
    if expr isa Expr && expr.head == :toplevel && length(expr.args) == 1
        return expr.args[1]
    end
    return expr
end

function cmdstring_string_literal(expr)
    expr = unwrap_toplevel_expr(expr)
    if expr isa Expr && expr.head == :macrocall
        for arg in expr.args[2:end]
            arg isa LineNumberNode && continue
            if arg isa String
                return arg
            elseif arg isa Expr && arg.head == :string
                all(x -> x isa String, arg.args) || return nothing
                return join(arg.args)
            end
        end
        return nothing
    elseif expr isa String
        return expr
    end
    return nothing
end

function collect_shell_interpolations!(exprs, part)
    if part isa Expr && part.head == :tuple
        for item in part.args
            collect_shell_interpolations!(exprs, item)
        end
    elseif part isa AbstractString
        return nothing
    else
        push!(exprs, part)
    end
    return nothing
end

# Parse the full cmd literal once so interpolation extraction follows Julia's grammar.
function cmdstring_interpolations_from_source(cmd_src::AbstractString)
    expr = Meta.parse(cmd_src; raise=false)
    expr isa Expr && expr.head == :error && return Any[]
    cmd_str = cmdstring_string_literal(expr)
    cmd_str === nothing && return Any[]
    parsed = try
        Base.shell_parse(cmd_str; special=Base.shell_special)[1]
    catch
        return Any[]
    end
    exprs = Any[]
    collect_shell_interpolations!(exprs, parsed)
    return exprs
end

function append_cmdstring_interpolations!(per_usage_info, leaf, processed_cmdstrings)
    cmd_node = cmdstring_parent(leaf)
    cmd_node === nothing && return nothing
    cmd_id = objectid(js_node(cmd_node))
    if cmd_id in processed_cmdstrings
        return nothing
    end
    push!(processed_cmdstrings, cmd_id)

    cmd_src = String(JuliaSyntax.sourcetext(js_node(cmd_node)))
    exprs = cmdstring_interpolations_from_source(cmd_src)
    isempty(exprs) && return nothing

    outer = analyze_name(leaf)
    outer_scope_path = outer.scope_path
    outer_module_path = outer.module_path
    wrapper = nodevalue(leaf)
    location = location_str(wrapper)

    for expr in exprs
        expr_src = sprint(Base.show_unquoted, expr)
        parsed = JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, expr_src; ignore_warnings=true)
        expr_wrapper = SyntaxNodeWrapper(parsed, wrapper.file, wrapper.bad_locations)
        cursor = TreeCursor(expr_wrapper)
        for expr_leaf in Leaves(cursor)
            if nodevalue(expr_leaf) isa SkippedFile
                continue
            end
            (kind(expr_leaf) in (K"Identifier", K"MacroName", K"StringMacroName"))::Bool ||
                continue
            parents_match(expr_leaf, (K"quote",)) &&
                !parents_match(expr_leaf, (K"quote", K".")) && continue

            name = get_val(expr_leaf)
            qualified_by = qualifying_module(expr_leaf)
            import_type = analyze_import_type(expr_leaf)
            explicitly_imported_by = import_type == :import_RHS ? get_import_lhs(expr_leaf) : nothing
            inner = analyze_name(expr_leaf)
            scope_path = vcat(inner.scope_path, outer_scope_path)
            push!(per_usage_info,
                  (; name,
                     qualified_by,
                     import_type,
                     explicitly_imported_by,
                     location,
                     inner...,
                     module_path=outer_module_path,
                     scope_path))
        end
    end
    return outer_module_path
end

"""
    analyze_all_names(file)

Returns a tuple of two items:

* `per_usage_info`: a table containing information about each name each time it was used
* `untainted_modules`: a set containing modules found and analyzed successfully
"""
function analyze_all_names(file)
    # we don't use `try_parse_wrapper` here, since there's no recovery possible
    # (no other files we know about to look at)
    tree = SyntaxNodeWrapper(file)
    # in local scope, a name refers to a global if it is read from before it is assigned to, OR if the global keyword is used
    # a name refers to a local otherwise
    # so we need to traverse the tree, keeping track of state like: which scope are we in, and for each name, in each scope, has it been used

    # Here we use a `TreeCursor`; this lets us iterate over the tree, while ensuring
    # we can call `parent` to climb up from a leaf.
    cursor = TreeCursor(tree)

    per_usage_info = @NamedTuple{name::Symbol,
                                 qualified_by::Union{Nothing,Vector{Symbol}},
                                 import_type::Symbol,
                                 explicitly_imported_by::Union{Nothing,Vector{Symbol}},
                                 location::String,
                                 function_arg::Bool,
                                 is_assignment::Bool,
                                 module_path::Vector{Symbol},
                                 scope_path::Vector{JuliaSyntax.SyntaxNode},
                                 struct_field_name::Bool,
                                 kwarg_name::Bool,
                                 struct_field_or_type_param::Bool,
                                 for_loop_index::Bool,
                                 generator_index::Bool,
                                 catch_arg::Bool,
                                 default_param_ctx::Union{Nothing,DefaultParamContext}}[]

    # we need to keep track of all names that we see, because we could
    # miss entire modules if it is an `include` we cannot follow.
    # Therefore, the "untainted" modules will be all the seen ones
    # minus all the explicitly tainted ones, and those will be the ones
    # safe to analyze.
    seen_modules = Set{Vector{Symbol}}()
    tainted_modules = Set{Vector{Symbol}}()
    processed_cmdstrings = Set{UInt}()

    for leaf in Leaves(cursor)
        if nodevalue(leaf) isa SkippedFile
            # we start from the parent
            mod_path = analyze_name(parent(leaf)).module_path
            push!(tainted_modules, mod_path)
            continue
        end

        if kind(leaf) == K"CmdString"
            mod_path = append_cmdstring_interpolations!(per_usage_info,
                                                        leaf,
                                                        processed_cmdstrings)
            mod_path === nothing || push!(seen_modules, mod_path)
            continue
        end

        # if we don't find any identifiers (or macro names) in a module, I think it's OK to mark it as
        # "not-seen"? Otherwise we need to analyze every leaf, not just the identifiers
        # and that sounds slow. Seems like a very rare edge case to have no identifiers...
        (kind(leaf) in (K"Identifier", K"MacroName", K"StringMacroName"))::Bool || continue

        # Skip quoted identifiers
        # This won't necessarily catch if they are part of a big quoted block,
        # but it will at least catch symbols (however keep qualified names)
        parents_match(leaf, (K"quote",)) && !parents_match(leaf, (K"quote", K".")) &&
            continue

        # Ok, we have a "name". We want to know if:
        # 1. it is being used in global scope
        # or 2. it is being used in local scope, but refers to a global binding
        # To figure out the latter, we check if it has been assigned before it has been used.
        #
        # We want to figure this out on a per-module basis, since each module has a different global namespace.

        location = location_str(nodevalue(leaf))
        name = get_val(leaf)
        qualified_by = qualifying_module(leaf)
        import_type = analyze_import_type(leaf)
        if import_type == :import_RHS
            explicitly_imported_by = get_import_lhs(leaf)
        else
            explicitly_imported_by = nothing
        end
        ret = analyze_name(leaf)
        push!(seen_modules, ret.module_path)
        push!(per_usage_info,
              (; name, qualified_by, import_type, explicitly_imported_by, location, ret...))
    end
    untainted_modules = setdiff!(seen_modules, tainted_modules)
    return analyze_per_usage_info(per_usage_info), untainted_modules
end

function is_name_internal_in_higher_local_scope(name, scope_path, seen; default_param_ctx=nothing)
    if default_param_ctx !== nothing && name in default_param_ctx.visible_names
        return true
    end
    # We will recurse up the `scope_path`. Note the order is "reversed",
    # so the first entry of `scope_path` is deepest.

    while !isempty(scope_path)
        # First, if we are directly in a module, then we don't want to recurse further.
        # We will just end up in a different module.
        if kind(first(scope_path)) == K"module"
            return false
        end
        # Ok, now pop off the first scope and check.
        scope_path = scope_path[2:end]
        ret = get(seen, (; name, scope_path=SyntaxNodeList(scope_path)), nothing)
        if ret === nothing
            # Not introduced here yet, trying recursing further
            continue
        else
            # return value is `is_global`, so negate it
            return !ret
        end
    end
    # Did not find a local introduction
    return false
end

# We implement a workaround for https://github.com/JuliaLang/JuliaSyntax.jl/issues/558
# Hashing and equality for SyntaxNodes were changed from object identity to a recursive comparison
# in JuliaSyntax 1.0. This is very slow and also not quite the semantics we want anyway.
# Here, we wrap our nodes in a custom type that only compares object identity.
struct SyntaxNodeList
    nodes::Vector{JuliaSyntax.SyntaxNode}
end

function Base.:(==)(a::SyntaxNodeList, b::SyntaxNodeList)
    return map(objectid, a.nodes) == map(objectid, b.nodes)
end
function Base.isequal(a::SyntaxNodeList, b::SyntaxNodeList)
    return isequal(map(objectid, a.nodes), map(objectid, b.nodes))
end

function Base.hash(a::SyntaxNodeList, h::UInt)
    return hash(map(objectid, a.nodes), h)
end

function analyze_per_usage_info(per_usage_info)
    # For each scope, we want to understand if there are any global usages of the name in that scope
    # First, throw away all qualified usages, they are irrelevant
    # Next, if a name is on the RHS of an import, we don't care, so throw away
    # Next, if the name is begin used at global scope, obviously it is a global
    # Otherwise, we are in local scope:
    #   1. Next, if the name is a function arg, then this is not a global name (essentially first usage is assignment)
    #   2. Otherwise, if first usage is assignment, then it is local, otherwise it is global
    seen = Dict{@NamedTuple{name::Symbol,scope_path::SyntaxNodeList},Bool}()
    return map(per_usage_info) do nt
        if (; nt.name, scope_path=SyntaxNodeList(nt.scope_path)) in keys(seen)
            return PerUsageInfo(; nt..., first_usage_in_scope=false,
                                external_global_name=missing,
                                analysis_code=IgnoredNonFirst)
        end
        if nt.qualified_by !== nothing
            return PerUsageInfo(; nt..., first_usage_in_scope=true,
                                external_global_name=missing,
                                analysis_code=IgnoredQualified)
        end
        if nt.import_type == :import_RHS
            return PerUsageInfo(; nt..., first_usage_in_scope=true,
                                external_global_name=missing,
                                analysis_code=IgnoredImportRHS)
        end
        if nt.kwarg_name
            # Keyword argument and named tuple keys don't bind locals or count as usages.
            external_global_name = false
            return PerUsageInfo(; nt..., first_usage_in_scope=true,
                                external_global_name,
                                analysis_code=IgnoredKwargName)
        end
        if nt.struct_field_name
            # Do not record struct field names in `seen`, otherwise they mask later
            # references with the same identifier in the surrounding scope.
            # Intentionally no `push!` to `seen` here.
            # (issue #111)
            external_global_name = false
            return PerUsageInfo(; nt..., first_usage_in_scope=true,
                                external_global_name,
                                analysis_code=InternalStruct)
        end

        # At this point, we have an unqualified name, which is not the RHS of an import, and it is the first time we have seen this name in this scope.
        # Is it global or local?
        # We will check a bunch of things:
        # * this name could be local due to syntax: due to it being a function argument, LHS of an assignment, a struct field or type param, or due to a loop index.
        for (is_local, reason) in
            ((nt.function_arg, InternalFunctionArg),
             (nt.struct_field_or_type_param, InternalStruct),
             (nt.for_loop_index, InternalForLoop),
             (nt.generator_index, InternalGenerator),
             (nt.catch_arg, InternalCatchArgument),
             # We check this last, since it is less specific
             # than e.g. `InternalForLoop` but can trigger in
             # some of the same cases
             (nt.is_assignment, InternalAssignment))
            if is_local
                external_global_name = false
                push!(seen,
                      (; nt.name, scope_path=SyntaxNodeList(nt.scope_path)) => external_global_name)
                return PerUsageInfo(; nt..., first_usage_in_scope=true,
                                    external_global_name,
                                    analysis_code=reason)
            end
        end
        # * this was the first usage in this scope, but it could already be used in a "higher" local scope. It is possible we have not yet processed that scope fully but we will assume we have (TODO-someday). So we will recurse up and check if it is a local name there.
        if is_name_internal_in_higher_local_scope(nt.name,
                                                  nt.scope_path,
                                                  seen;
                                                  default_param_ctx=nt.default_param_ctx)
            external_global_name = false
            push!(seen,
                  (; nt.name, scope_path=SyntaxNodeList(nt.scope_path)) => external_global_name)
            return PerUsageInfo(; nt..., first_usage_in_scope=true, external_global_name,
                                analysis_code=InternalHigherScope)
        end

        external_global_name = true
        push!(seen,
              (; nt.name, scope_path=SyntaxNodeList(nt.scope_path)) => external_global_name)
        return PerUsageInfo(; nt..., first_usage_in_scope=true, external_global_name,
                            analysis_code=External)
    end
end

function get_global_names(per_usage_info)
    names_used_for_global_bindings = Set{@NamedTuple{name::Symbol,
                                                     module_path::Vector{Symbol},
                                                     location::String}}()

    for nt in per_usage_info
        if nt.external_global_name === true
            push!(names_used_for_global_bindings, (; nt.name, nt.module_path, nt.location))
        end
    end
    return names_used_for_global_bindings
end

function get_explicit_imports(per_usage_info)
    explicit_imports = Set{@NamedTuple{name::Symbol,
                                       module_path::Vector{Symbol},
                                       location::String}}()
    for nt in per_usage_info
        # skip qualified names
        (nt.qualified_by === nothing) || continue
        if nt.import_type == :import_RHS
            push!(explicit_imports, (; nt.name, nt.module_path, nt.location))
        end
    end
    return explicit_imports
end

drop_metadata(nt) = (; nt.name, nt.module_path)
function setdiff_no_metadata(set1, set2)
    remove = Set(drop_metadata(nt) for nt in set2)
    return Set(nt for nt in set1 if drop_metadata(nt) ∉ remove)
end

"""
    get_names_used(file) -> FileAnalysis

Figures out which global names are used in `file`, and what modules they are used within.

Traverses static `include` statements.

Returns a `FileAnalysis` object.
"""
function get_names_used(file)
    check_file(file)
    # Here we get 1 row per name per usage
    per_usage_info, untainted_modules = analyze_all_names(file)

    names_used_for_global_bindings = get_global_names(per_usage_info)
    explicit_imports = get_explicit_imports(per_usage_info)

    # name used to point to a global which was not explicitly imported
    needs_explicit_import = setdiff_no_metadata(names_used_for_global_bindings,
                                                explicit_imports)
    unnecessary_explicit_import = setdiff_no_metadata(explicit_imports,
                                                      names_used_for_global_bindings)

    return FileAnalysis(; per_usage_info, needs_explicit_import,
                        unnecessary_explicit_import,
                        untainted_modules)
end
