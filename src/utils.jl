"""
Function returning the name of a `where` parameter
"""
function get_param_name(expr) :: Symbol
  @capture(expr, arg_<:arg_type_) && return arg
  @capture(expr, arg_) && return arg
end

"""
Function returning the arguments of a function definition
"""
function get_args(func_def::Dict)
  arg_dict = Dict{Symbol, Any}()
  arg_list = Vector{Symbol}()
  kwarg_list = Vector{Symbol}()
  for arg in (func_def[:args]...,)
    arg_def = splitarg(arg)
    if arg_def[1] !== nothing
      push!(arg_list, arg_def[1])
      arg_dict[arg_def[1]] = arg_def[3] ? Any : arg_dict[arg_def[1]] = arg_def[2]
    end
  end
  for arg in (func_def[:kwargs]...,)
    arg_def = splitarg(arg)
    push!(kwarg_list, arg_def[1])
    arg_dict[arg_def[1]] = arg_def[3] ? Any : arg_dict[arg_def[1]] = arg_def[2]
  end
  arg_list, kwarg_list, arg_dict
end

"""
Takes a function definition and returns the expressions needed to forward the arguments to an inner function.
For example `function foo(a, ::Int, c...; x, y=1, z...)` will
1. modify the function to `gensym()` nameless arguments
2. return `(:a, gensym(), :(c...)), (:x, :y, :(z...)))`
"""
function forward_args(func_def)
  args = []
  map!(func_def[:args], func_def[:args]) do arg
    name, type, splat, default = splitarg(arg)
    name = something(name, gensym())
    if splat
      push!(args, :($name...))
    else
      push!(args, name)
    end
    combinearg(name, type, splat, default)
  end
  kwargs = []
  for arg in func_def[:kwargs]
    name, type, splat, default = splitarg(arg)
    if splat
      push!(kwargs, :($name...))
    else
      push!(kwargs, name)
    end
  end
  args, kwargs
end

const unused = (Symbol("#temp#"), Symbol("_"), Symbol(""), Symbol("#unused#"), Symbol("#self#"))

function strip_defaults(arg_exprs::Vector{Any})
  return Any[@capture(arg_expr, arg_expr2_ = default_) ? arg_expr2 : arg_expr
    for arg_expr in arg_exprs]
end

"""
Function returning the slots of a function definition
"""
function get_slots(func_def::Dict, args::Dict{Symbol, Any}, mod::Module)
  slots = Dict{Symbol, Any}()
  func_def[:name] = gensym()
  func_def[:args] = Any[strip_defaults(func_def[:args])..., strip_defaults(func_def[:kwargs])...]
  func_def[:kwargs] = []
  # replace yield with inference barrier
  func_def[:body] = postwalk(transform_yield, func_def[:body])
  # collect items to skip
  nosaves = Set{Symbol}()
  func_def[:body] = postwalk(x->transform_nosave(x, nosaves), func_def[:body])
  # eval function
  func_expr = combinedef(func_def) |> flatten
  inferfn = @eval(mod, @noinline $func_expr)
  #@info func_def[:body] |> striplines
  # get typed code
  m = only(methods(inferfn, Tuple))
  codeinfo = only(code_typed(inferfn, Tuple; optimize=false))
  #@info codeinfos
  # extract slot names and types
  for (name, type) in collect(zip(codeinfo.first.slotnames, codeinfo.first.slottypes))
    name ∉ nosaves && name ∉ unused && (slots[name] = Union{type, get(slots, name, Union{})})
  end
  # remove `catch exc` statements
  postwalk(x->remove_catch_exc(x, slots), func_def[:body])
  # set error branches to `Any`
  for (key, val) in slots
    if val === Union{}
      slots[key] = Any
    end
  end
  return m, slots
end

"""
Function removing the `exc` symbol of a `catch exc` statement of a list of slots.
"""
function remove_catch_exc(expr, slots::Dict{Symbol, Any})
  @capture(expr, (try body__ catch exc_; handling__ end) | (try body__ catch exc_; handling__ finally always__ end)) && delete!(slots, exc)
  expr
end

struct IteratorReturn{T}
  value :: T
  IteratorReturn(value) = new{typeof(value)}(value)
end

@inline function generate(fsm_iter::FiniteStateMachineIterator, send, state=nothing)
  #fsm_iter._state = state
  result = fsm_iter(send)
  fsm_iter._state === 0xff && return IteratorReturn(result)
  result, nothing
end

@inline function generate(iter, _)
  ret = iterate(iter)
  isnothing(ret) && return IteratorReturn(nothing)
  ret
end

@inline function generate(iter, _, state)
  ret = iterate(iter, state)
  isnothing(ret) && return IteratorReturn(nothing)
  ret
end

struct FSMIGenerator
  m::Method
end

intersection_env(@nospecialize(x), @nospecialize(y)) = ccall(:jl_type_intersection_with_env, Any, (Any,Any), x, y)::Core.SimpleVector

@static if VERSION >= v"1.12" # static macro prevents JET/Revise from making mistakes here when analyzing the file
  using Base: invoke_in_typeinf_world
else
  function invoke_in_typeinf_world(args...)
    vargs = Any[args...]
    return ccall(:jl_call_in_typeinf_world, Any, (Ptr{Any}, Cint), vargs, length(vargs))
  end
end

function code_typed_by_method(method::Method, @nospecialize(tt::Type), world::UInt)
  # run inference (TODO: not really allowed or safe in a generated function)
  (ti, sparams) = intersection_env(tt, method.sig)
  interp = Core.Compiler.NativeInterpreter(world)
  frame = invoke_in_typeinf_world(Core.Compiler.typeinf_frame, interp, method, tt, sparams::Core.SimpleVector, false)
  frame === nothing && error("inference failed")
  ci = frame.src
  @static if VERSION >= v"1.12"
    ci.edges = Core.svec(frame.edges...) # Core.Compiler seems to forget to do this
  end
  return frame.linfo, ci
end

function (fsmi_generator::FSMIGenerator)(world::UInt, source, typed_fsmitype, fsmitype::Type{Type{T_}}, fargtypes) where T_
    @nospecialize
    # get typed code of the inference function evaluated in get_slots
    # using the concrete argument types
    T = T_
    m = fsmi_generator.m
    stub = Core.GeneratedFunctionStub(identity, Core.svec(:var"#self#", :fsmi, :fargs), Core.svec())
    fargtypes = Tuple{fargtypes...} # convert (types...) to Tuple{types...}
    mi, ci = try
      code_typed_by_method(m, fargtypes, world)
    catch err # inference failed, return generic type
      @safe_warn "Inference of a @resumable function failed -- a slower fallback will be used and everything will still work, however please consider reporting this to the developers of ResumableFunctions.jl so that we can debug and increase performance"
      @safe_warn "The error was $err"
      return stub(world, source, :(return $T())) # use typed_fsmi_fallback implementation
    end
    # extract slot types
    cislots = Dict{Symbol, Any}()
    names = ci.slotnames
    types = ci.slottypes
    for i in eachindex(names)
      # take care to widen types that are unstable or Const
      name = names[i]
      type = Core.Compiler.widenconst(types[i])
      cislots[name] = Union{type, get(cislots, name, Union{})}
    end
    slots = map(slot->get(cislots, slot, Any), fieldnames(T)[2:end])
    # instantiate the concrete type
    if !isempty(slots)
      T = T{slots...}
    end
    new_ci = stub(world, source, :(return $T()))
    edges = ci.edges
    if edges !== nothing && !isempty(edges)
      # Inference may have conservatively limited the world range, even though it also concluded there was no restrictions (hence no edges) necessary.
      new_ci.min_world = ci.min_world
      new_ci.max_world = ci.max_world
      new_ci.edges = edges
    end
    return new_ci
end

# a fallback function that uses the fallback constructor with generic slot types
# useful for older versions of Julia or for situations where our current custom inference struggles
function typed_fsmi_fallback(fsmi::Type{T}, fargs...)::T where T
  return T()
end

################################################################################
#
#  Scoping
#
################################################################################

# As every modern programming language, julia has the concept of variable scope,
# see https://docs.julialang.org/en/v1/manual/variables-and-scoping/.
#
# For example, in the following example, there are actual two variables.
# This can be seen by rewriting this as on the right hand side.
#
# a = 1         | a_1 = 1
# let a = a     | begin
#   a = 2       |   a_2 = a_1; a_2 = 2
# end           | end
#
# A similar phenomen happens with `local`
#
# x = 1           | x_1 = 1
# begin           | begin
#   local x = 0   |   x_2 = 0
# end             | end
#
# Simulating a function using a finite state machine (FSM) has a disadvantage
# that it cannot handle expressions, where identical left-hand sides (RHS)
# refer to different variables. This applies to both `let` as well as `local`
# constructions.
#
# We solve this problem by renaming all variables.
#
# We use a ScopeTracker type to keep track of the things that are already
# renamed. It is basically just a Vector{Dict{Symbol, Symbol}},
# representing a stack, where the top records the renamed variables in the
# current scope.
#
# The renaming is done as follows. If we encounter an assignment of the form
# x = y
# there are two cases for x:
#   1) x has been seen before in some scope. Then we replace x accordingly.
#   2) x has not been seen before. We give x a new name and store :x => :x_new
#      in current scope.
#
# This is done in lookup_lhs!. Note that some construction, like `let`, create
# a new variable in a new scope. This is handled by the `new` keyword.
#
# For any other symbol y (which is not the left hand side of an assignment),
# there are the following two cases:
#   1) y has been seen before in some scope. Then we replace y accordingly.
#   2) y has not been seen before, then we don't rename it.
#
# ---
#
# Note that we handle local x, by emitting a new variable :x => :x_new
# inside the current scope.
#
# We exploit this when rewriting let and for constructions, see below for
# examples with let. At the end, all `local x` are removed.

abstract type AbstractScopingBackend end

"""
Default scoping backend used by `@resumable`.

This preserves the current hand-rolled scope-renaming pass while allowing
experimental backends to be introduced behind a stable seam.
"""
struct ManualScopingBackend <: AbstractScopingBackend end

"""
Experimental scoping backend placeholder for future JuliaLowering-backed scope
resolution.

This backend is intentionally not wired up yet. The current proven first slice
is much narrower than full scope resolution: generator/filter-only proof cases
under Julia 1.12+ with explicit normalization of lowering artifacts.
"""
struct JuliaLoweringScopingBackend <: AbstractScopingBackend end

mutable struct ScopeTracker
  i::Int
  mod::Module
  scope_stack::Vector
end

default_scoping_backend() = ManualScopingBackend()

function init_scope_tracker(args, kwargs, name, params, mod::Module)
  ScopeTracker(0, mod, [Dict(i => i for i in vcat(args, kwargs, [name], params...))])
end

function scope_function_body(expr, args, kwargs, name, params, mod::Module;
                             backend::AbstractScopingBackend = default_scoping_backend())
  scope = init_scope_tracker(args, kwargs, name, params, mod)
  scope_function_body(expr, scope, backend)
end

function scope_function_body(expr, scope::ScopeTracker, ::ManualScopingBackend)
  scoping(copy(expr), scope)
end

function experimental_generator_filter_slice_supported(expr::Expr)
  expr.head === :generator || return false
  length(expr.args) == 2 || return false

  iter_node = expr.args[2]
  if iter_node isa Expr && iter_node.head === :filter
    length(iter_node.args) == 2 || return false
    iter_node = iter_node.args[2]
  end

  iter_node isa Expr || return false
  iter_node.head === :(=) || return false
  iter_node.args[1] isa Symbol || return false
  true
end

experimental_generator_filter_slice_supported(::Any) = false

function experimental_generator_filter_slice_status(expr::Expr)
  (supported = experimental_generator_filter_slice_supported(expr), contract_met = false)
end

function experimental_visible_outer_bindings(scope::ScopeTracker)
  outer_bindings = Symbol[]
  seen = Set{Symbol}()
  for frame in scope.scope_stack
    for name in keys(frame)
      if name ∉ seen
        push!(outer_bindings, name)
        push!(seen, name)
      end
    end
  end
  outer_bindings
end

function experimental_generator_filter_slice_readiness(expr::Expr, scope::ScopeTracker)
  supported = experimental_generator_filter_slice_supported(expr)
  outer_bindings = experimental_visible_outer_bindings(scope)

  contract_met = if supported && VERSION >= v"1.12.0"
    expr_src = sprint(Base.show_unquoted, expr)
    try
      experimental_generator_binding_contract_met(expr_src; outer_bindings = outer_bindings, mod = scope.mod)
    catch err
      if err isa ArgumentError
        false
      else
        rethrow()
      end
    end
  else
    false
  end

  (supported = supported, outer_bindings = outer_bindings, contract_met = contract_met)
end

function experimental_generator_filter_slice_status(expr::Expr, scope::ScopeTracker)
  readiness = experimental_generator_filter_slice_readiness(expr, scope)
  (supported = readiness.supported, contract_met = readiness.contract_met)
end

experimental_generator_filter_slice_status(::Any) = (supported = false, contract_met = false)

function scope_function_body(expr, scope::ScopeTracker, ::JuliaLoweringScopingBackend)
  status = experimental_generator_filter_slice_status(expr, scope)
  if status.supported && status.contract_met
    return scope_function_body(expr, scope, ManualScopingBackend())
  elseif status.supported
    throw(ArgumentError(
      "JuliaLowering scoping backend is experimental; this generator/filter first slice is recognized but not wired into ResumableFunctions yet"
    ))
  end
  throw(ArgumentError(
    "JuliaLowering scoping backend is experimental; the current proven slice is generator/filter-only proof work and this expression is outside that slice"
  ))
end

"""
Proof-only helper for experimenting with JuliaLowering-backed scope analysis.

This does not affect the normal `@resumable` pipeline. It is intended for
narrow diagnostics and feasibility checks while the JuliaLowering path remains
experimental.
"""
function experimental_julialowering_scope_report(expr_src::AbstractString; mod::Module = Main)
  if VERSION < v"1.12.0"
    throw(ArgumentError(
      "experimental_julialowering_scope_report requires Julia 1.12+; current VERSION=$(VERSION)"
    ))
  end

  jl = if isdefined(Main, :JuliaLowering)
    getfield(Main, :JuliaLowering)
  else
    throw(ArgumentError(
      "JuliaLowering is not loaded in Main; start Julia 1.12+ and `using JuliaLowering` before calling experimental_julialowering_scope_report"
    ))
  end

  js = try
    getfield(jl, :JuliaSyntax)
  catch
    throw(ArgumentError("JuliaLowering loaded but JuliaSyntax is not available through it"))
  end

  ex = js.parsestmt(jl.SyntaxTree, expr_src)
  lowered = jl.lower(mod, ex)
  return sprint(io -> show(io, MIME("text/plain"), lowered))
end

"""
Collect a small structured summary of JuliaLowering scope-related nodes.

This is a proof-only helper for the experimental JuliaLowering path. It returns
ordered occurrences of `:slot` and `:globalref` nodes from the lowered tree so
future mapping code can compare structure without scraping pretty-printed text.
"""
function experimental_julialowering_binding_summary(expr_src::AbstractString; mod::Module = Main)
  if VERSION < v"1.12.0"
    throw(ArgumentError(
      "experimental_julialowering_binding_summary requires Julia 1.12+; current VERSION=$(VERSION)"
    ))
  end

  jl = if isdefined(Main, :JuliaLowering)
    getfield(Main, :JuliaLowering)
  else
    throw(ArgumentError(
      "JuliaLowering is not loaded in Main; start Julia 1.12+ and `using JuliaLowering` before calling experimental_julialowering_binding_summary"
    ))
  end

  js = try
    getfield(jl, :JuliaSyntax)
  catch
    throw(ArgumentError("JuliaLowering loaded but JuliaSyntax is not available through it"))
  end

  ex = js.parsestmt(jl.SyntaxTree, expr_src)
  lowered = jl.lower(mod, ex)
  out = NamedTuple{(:kind, :var_id, :name)}[]

  function walk(node)
    k = Symbol(jl.kind(node))
    if k === :slot
      push!(out, (kind = k, var_id = getproperty(node, :var_id), name = nothing))
    elseif k === :globalref
      push!(out, (kind = k, var_id = nothing, name = getproperty(node, :name_val)))
    end
    for i in 1:jl.numchildren(node)
      walk(node[i])
    end
    nothing
  end

  walk(lowered)
  out
end

"""
Return a lightly normalized JuliaLowering binding summary.

This proof helper currently strips synthetic wrapper globals introduced by
JuliaLowering for anonymous closure/lambda scaffolding (for example `#->##0`).
That makes narrow generator/comprehension comparisons less noisy without
claiming full structural equivalence.
"""
function experimental_julialowering_binding_summary_normalized(expr_src::AbstractString; mod::Module = Main)
  raw = experimental_julialowering_binding_summary(expr_src; mod = mod)
  filter(raw) do item
    !(item.kind === :globalref && item.name isa AbstractString && occursin(r"^#->##\d+$", item.name))
  end
end

"""
Return a tiny comparison summary for generator/filter proof cases.

This is intentionally narrow: it compares the current manual scoping proof helper
against the normalized JuliaLowering proof helper using only stable summary
signals that already appear close on generator/filter examples.
"""
function experimental_generator_binding_comparison(expr_src::AbstractString;
                                                   outer_bindings::AbstractVector{Symbol} = Symbol[],
                                                   mod::Module = Main)
  manual = experimental_manual_binding_summary(expr_src; outer_bindings = outer_bindings, mod = mod)
  jl = experimental_julialowering_binding_summary_normalized(expr_src; mod = mod)

  manual_globalrefs = [String(item.name) for item in manual if item.kind === :globalref]
  jl_globalrefs = [String(item.name) for item in jl if item.kind === :globalref]
  manual_slot_refs = count(item -> item.kind === :localref, manual)
  jl_slot_refs = count(item -> item.kind === :slot, jl)
  manual_distinct_slots = length(unique(item.local_id for item in manual if item.kind === :localref))
  jl_distinct_slots = length(unique(item.var_id for item in jl if item.kind === :slot))
  manual_semantic_slot_refs = manual_slot_refs - manual_distinct_slots

  (
    manual_globalrefs = manual_globalrefs,
    jl_globalrefs = jl_globalrefs,
    globalrefs_match = manual_globalrefs == jl_globalrefs,
    manual_slot_refs = manual_slot_refs,
    manual_semantic_slot_refs = manual_semantic_slot_refs,
    jl_slot_refs = jl_slot_refs,
    semantic_slot_refs_match = manual_semantic_slot_refs == jl_slot_refs,
    manual_distinct_slots = manual_distinct_slots,
    jl_distinct_slots = jl_distinct_slots,
  )
end

"""
Return whether an expression fits the current first adapter slice.

Current scope is intentionally narrow:
- generator expressions only
- optional `if` filter allowed
- exactly one binder assignment
- symbol binder only
"""
function experimental_generator_filter_slice_supported(expr_src::AbstractString)
  expr = Meta.parse(expr_src)
  experimental_generator_filter_slice_supported(expr)
end

"""
Return whether a generator/filter case satisfies the current first-slice proof contract.

This stays intentionally narrow and proof-only. It uses the generator comparison
helper and checks only the stable signals that the current first adapter target
claims as acceptance criteria.
"""
function experimental_generator_binding_contract_met(expr_src::AbstractString;
                                                     outer_bindings::AbstractVector{Symbol} = Symbol[],
                                                     mod::Module = Main)
  experimental_generator_filter_slice_supported(expr_src) || return false
  cmp = experimental_generator_binding_comparison(expr_src; outer_bindings = outer_bindings, mod = mod)
  cmp.globalrefs_match || return false
  cmp.semantic_slot_refs_match || return false
  cmp.manual_distinct_slots == cmp.jl_distinct_slots || return false
  true
end

"""
Return a compact preflight status for the current first adapter slice.

This is a proof-only convenience helper for future experimental adapter work.
It centralizes the current shape gate and contract check in one call.
"""
function experimental_generator_filter_slice_status(expr_src::AbstractString;
                                                    outer_bindings::AbstractVector{Symbol} = Symbol[],
                                                    mod::Module = Main)
  expr = Meta.parse(expr_src)
  base = experimental_generator_filter_slice_status(expr)
  contract_met = base.supported && VERSION >= v"1.12.0" && experimental_generator_binding_contract_met(expr_src; outer_bindings = outer_bindings, mod = mod)
  (supported = base.supported, contract_met = contract_met)
end

"""
Collect a small structured summary of the current manual scoping pass.

This mirrors the proof-only JuliaLowering binding summary helper on the same
string input so narrow shadowing cases can be compared structurally. The helper
tracks local bindings introduced by the scoped expression and emits ordered
`:localref` / `:globalref` occurrences.
"""
function experimental_manual_binding_summary(expr_src::AbstractString;
                                             outer_bindings::AbstractVector{Symbol} = Symbol[],
                                             mod::Module = Main)
  expr = Meta.parse(expr_src)
  scoped = scope_function_body(expr, collect(outer_bindings), Symbol[], gensym(:manual_scope), Symbol[], mod)

  out = NamedTuple{(:kind, :local_id, :name)}[]
  local_ids = Dict{Symbol, Int}()
  next_local_id = Ref(0)
  assigned_locals = Set{Symbol}()
  generator_locals = Set{Symbol}()

  function collect_assigned_locals!(node)
    if node isa Expr
      if node.head === :(=)
        lhs = node.args[1]
        if lhs isa Symbol
          push!(assigned_locals, lhs)
        elseif lhs isa Expr && lhs.head === :tuple
          for arg in lhs.args
            arg isa Symbol && push!(assigned_locals, arg)
          end
        end
      end
      for arg in node.args
        collect_assigned_locals!(arg)
      end
    end
    nothing
  end

  function collect_generator_locals!(node, in_generator::Bool = false)
    if node isa Expr
      next_in_generator = in_generator || node.head === :generator || node.head === :filter
      if next_in_generator && node.head === :(=)
        lhs = node.args[1]
        if lhs isa Symbol
          push!(generator_locals, lhs)
        elseif lhs isa Expr && lhs.head === :tuple
          for arg in lhs.args
            arg isa Symbol && push!(generator_locals, arg)
          end
        end
      end
      for arg in node.args
        collect_generator_locals!(arg, next_in_generator)
      end
    end
    nothing
  end

  function ensure_local!(sym::Symbol)
    get!(local_ids, sym) do
      next_local_id[] += 1
      next_local_id[]
    end
  end

  function emit_symbol(sym::Symbol)
    if sym in generator_locals && !haskey(local_ids, sym)
      ensure_local!(sym)
    end
    if haskey(local_ids, sym)
      push!(out, (kind = :localref, local_id = local_ids[sym], name = sym))
    else
      push!(out, (kind = :globalref, local_id = nothing, name = sym))
    end
    nothing
  end

  function walk(node)
    if node isa Symbol
      emit_symbol(node)
    elseif node isa Expr
      if node.head === :local
        for arg in node.args
          if arg isa Symbol
            ensure_local!(arg)
            arg ∉ assigned_locals && emit_symbol(arg)
          end
        end
      elseif node.head === :(=)
        for i in 2:length(node.args)
          walk(node.args[i])
        end
        walk(node.args[1])
      else
        for arg in node.args
          walk(arg)
        end
      end
    end
    nothing
  end

  collect_assigned_locals!(scoped)
  collect_generator_locals!(scoped)
  walk(scoped)
  out
end

function lookup_lhs!(s::Symbol, S::ScopeTracker; new::Bool = false)
  if !new
    for D in Iterators.reverse(S.scope_stack)
      if haskey(D, s)
        return D[s]
      end
    end
  end
  D = last(S.scope_stack)
  new_s = Symbol(s, Symbol("_$(S.i)"))
  S.i += 1
  D[s] = new_s
  return new_s
end

function lookup_lhs!(s::QuoteNode, S::ScopeTracker)
  return s
end

function lookup_lhs!(s::Expr, S::ScopeTracker; new = false)
  if s.head === :(.)
    s.args[1] = lookup_lhs!(s.args[1], S; new = new)
    return s
  end
  if s.head  === :tuple
    # we should never have to treat a (;a) = b here
    (s.args[1] isa Expr && s.args[1].head === :parameters) &&
        error("Illegal tuple expression in scope lookup: $(s.args[1])")

    # we should have an innocent (a, b, c) = ...
    for i in 1:length(s.args)
      s.args[i] = lookup_lhs!(s.args[i], S; new = new)
    end
    return s
  end
  if s.head === :ref
    s = scoping(s, S)
    return s
  end
  error("Not captured")
end

lookup_rhs!(e::typeof(ResumableFunctions.generate), scope) = e

function lookup_rhs!(s::Symbol, S::ScopeTracker)
  for D in Iterators.reverse(S.scope_stack)
    if haskey(D, s)
      return D[s]
    end
  end
  return s
end

scoping(e::LineNumberNode, scope) = e
scoping(e::Int, scope) = e
scoping(e::Float64, scope) = e
scoping(e::String, scope) = e
scoping(e::typeof(ResumableFunctions.generate), scope) = e
scoping(e::typeof(ResumableFunctions.IteratorReturn), scope) = e
scoping(e::QuoteNode, scope) = e
scoping(e::Bool, scope) = e
scoping(e::Nothing, scope) = e
scoping(e::GlobalRef, scope) = e

function scoping(s::Symbol, scope; new = false)
  return lookup_rhs!(s, scope)
end

function scope_generator_inner(expr, scope)
  for i in 2:length(expr.args)
    !(expr.args[i] isa Expr && expr.args[i].head === :(=)) &&
      error("Illegal expression in generator: $(expr.args[i])")
    expr.args[i].args[2] = scoping(expr.args[i].args[2], scope)
  end
  # now create new scope
  push!(scope.scope_stack, Dict())
  for i in 2:length(expr.args)
    expr.args[i].args[1] = lookup_lhs!(expr.args[i].args[1], scope, new = true)
  end
end

function scope_generator(expr, scope)
  expr.head !== :generator && error("Illegal generator expression: $(expr)")

  has_filter = length(expr.args) == 2 && expr.args[2] isa Expr && expr.args[2].head === :filter
  if has_filter
    ex = expr.args[2]
    scope_generator_inner(ex, scope)
    # now apply scoping to the filter condition expression
    ex.args[1] = scoping(ex.args[1], scope)
  else
    scope_generator_inner(expr, scope)
  end
  expr.args[1] = scoping(expr.args[1], scope)
  pop!(scope.scope_stack)
  return expr
end

function scoping(expr::Expr, scope)
  if expr.head === :generator
    return scope_generator(expr, scope)
  end

  # Named tuple handling is again pretty awkward
  # because of the (;a, b) syntax, which we have to expand by hand to
  # (;a = a, b = b), otherwise we do (;a_1, b_2), and this gets
  # (;a_1 = a_1, b_2 = b_2) which is nonsensical
  if expr.head === :tuple
    if length(expr.args) > 0 && expr.args[1] isa Expr && expr.args[1].head === :parameters
      # this is a named tuple of the form (;...)
      # TODO: named tuple recognition not working properly yet
      # first bring (;...,b,...) in the form (;...,b = b,...)
      for i in 1:length(expr.args[1].args)
        if !(expr.args[1].args[i] isa Expr)
          expr.args[1].args[i] = Expr(:kw, expr.args[1].args[i], expr.args[1].args[i])
        end
      end
      # Now rename the RHS
      for i in 1:length(expr.args[1].args)
        !(expr.args[1].args[i] isa Expr && expr.args[1].args[i].head === :kw) &&
          error("Illegal expression in named tuple: $(expr.args[1].args[i])")
        expr.args[1].args[i].args[2] = scoping(expr.args[1].args[i].args[2], scope)
      end
      return expr
    elseif any(a -> a isa Expr && a.head === :(=), expr.args[1:end])
      # Can be any of (a = 2, b, c = d)
      # lets first normalize the entries of the form b to b => scoping(b, ...)
      for i in 1:length(expr.args)
        if expr.args[i] isa Symbol
          expr.args[i] = Expr(:kw, expr.args[i], lookup_lhs!(expr.args[i], scope))
        else
          expr.args[i].head !== :(=) &&
            error("Unrecognized expression in tuple: $(expr.args[i])")
          expr.args[i].args[2] = scoping(expr.args[i].args[2], scope)
          expr.args[i].head = :kw
        end
      end
      # Let's normalize to a parameter (;...) form
      expr.args[1] = Expr(:parameters, expr.args...)
      expr.args = expr.args[1:1]
      return expr
    end
  end

  if expr.head === :call
    # Rename the caller name
    expr.args[1] = scoping(expr.args[1], scope)
    # We have to not rename the keyword arguments
    # Super awkward because of f(x, y = z, w) and f(x; y) is allowed :(
    # Or even f(x, y = 1, w, z = 2)
    for i in 2:length(expr.args)
      if expr.args[i] isa Expr && expr.args[i].head === :kw
        # this is f(..., x = 2, ...)
        expr.args[i].args[2] = scoping(expr.args[i].args[2], scope)
      elseif expr.args[i] isa Expr && expr.args[i].head === :parameters
        # this is f(...;...)
        # first normalize f(...;...,x...) to f(...;..., x = x,...)
        for j in 1:length(expr.args[i].args)
          if !(expr.args[i].args[j] isa Expr)
            expr.args[i].args[j] = Expr(:kw, expr.args[i].args[j], expr.args[i].args[j])
          end
        end
        for j in 1:length(expr.args[i].args)
          !(expr.args[i].args[j] isa Expr && expr.args[i].args[j].head === :kw) &&
            error("Unrecognized keyword expression: $(expr.args[i].args[j])")
          # this is f(...; x = 2)
          expr.args[i].args[j].args[2] = scoping(expr.args[i].args[j].args[2], scope)
        end
      else
        expr.args[i] = scoping(expr.args[i], scope)
      end
    end
    return expr
  end

  if expr.head === :(=)
    # One special case, where we need to have both LHS and RHS at our hands
    if expr.args[1] isa Expr && expr.args[1].head === :tuple && expr.args[1].args[1] isa Expr && expr.args[1].args[1].head === :parameters
      # OK, so this (;a, b) = c
      # lets transform this into
      # d = c # because c could be an expression itself
      # a_new = d.a
      # b_new = d.b
      d = gensym()
      res = [quote $(d) = $(expr.args[2]); end]
      for i in 1:length(expr.args[1].args[1].args)
        lhs = expr.args[1].args[1].args[i]
        !(lhs isa Symbol) &&
          error("Unrecognized expression in named tuple assignment: $(lhs)")
        lhslookup = lookup_lhs!(lhs, scope)
        push!(res, quote $(lhslookup) = $(d).$(lhs) end)
      end
      return quote $(res...) end
    end

    # first transform the RHS (this can be anything) to check for shadowing of globals
    for i in 2:length(expr.args)
      expr.args[i] = scoping(expr.args[i], scope)
    end

    # only then deal with the LHS (it is a symbol or a tuple of symbols)
    expr.args[1] = lookup_lhs!(expr.args[1], scope)

    return expr
  end
  if expr.head === :macrocall
    for i in 2:length(expr.args)
      expr.args[i] = scoping(expr.args[i], scope)
    end
    return expr
  end
  if expr.head === :let
    # Replace
    #   let i, k = 2, j = 1
    #      [...]
    #   end
    #
    #   by
    #
    #   let
    #     local i_new
    #     local k_new = 2
    #     local j_new = 1
    #   end
    #
    #   Caveat:
    #   let i = i, j = i
    #
    #   must be
    #   new_i = old_i
    #   new_j = new_i
    #
    #   Thus we add a new scope, resolve the RHS and force the LHS to be new.
    #   Do this one after the other and everything will be fine.

    @capture(expr, let arg_; body_ end) || return expr
    @capture(arg, begin x__ end)
    push!(scope.scope_stack, Dict())
    rep = []
    for i in 1:length(x)
      y = x[i]
      fl = @capture(y, k_ = v_)
      if fl
        replace_rhs = scoping(v, scope)
        replace_lhs = lookup_lhs!(k, scope, new = true)
        push!(rep, quote local $(replace_lhs); $(replace_lhs) = $(replace_rhs) end)
      else
        !(y isa Symbol) &&
          error("Unrecognized expression in let expression: $(y)")
        replace_lhs = lookup_lhs!(y, scope, new = true)
        push!(rep, quote local $(replace_lhs) end)
      end
    end
    rep = quote
      $(rep...)
    end
    rep = flatten(rep)
    expr.args[1] = Expr(:block)
    pushfirst!(expr.args[2].args, rep)

    # Now continue recursively
    # but skip the local/dance, since we already replaced them
    for i in 2:length(expr.args[2].args)
      a = expr.args[2].args[i]
      expr.args[2].args[i] = scoping(a, scope)
    end
    pop!(scope.scope_stack)
    return expr
  end

  new_stack = false
  if expr.head === :while
    push!(scope.scope_stack, Dict())
    new_stack = true
  end

  if expr.head === :local
    # if we see a local x or local x = ...
    # we always emit a new identifier
    if length(expr.args) == 1 && expr.args[1] isa Symbol
      expr.args[1] = lookup_lhs!(expr.args[1], scope)
    elseif length(expr.args) == 1 && expr.args[1].head === :tuple
      for i in 1:length(expr.args[1].args)
        a = expr.args[1].args[i]
        expr.args[1].args[i] = lookup_lhs!(a, scope)
      end
    else
      # this is local x = y
      !(length(expr.args) == 1 && expr.args[1] isa Expr && expr.args[1].head === :(=)) &&
        error("Illegal local expression: $(expr.args)")
      expr.args[1].args[1] = lookup_lhs!(expr.args[1].args[1], scope)
      expr.args[1].args[2] = scoping(expr.args[1].args[2], scope)
      expr = quote local $(expr.args[1].args[1]); $(expr.args[1].args[1]) = $(expr.args[1].args[2]); end
    end
    return expr
  end

  # default
  for i in 1:length(expr.args)
    a = expr.args[i]
    expr.args[i] = scoping(a, scope)
  end

  if new_stack
    pop!(scope.scope_stack)
  end
  return expr
end
