"""
Function returning the name of a where parameter
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
    if arg_def[1] != nothing
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

"""
Function returning the slots of a function definition
"""
function get_slots(func_def::Dict, args::Dict{Symbol, Any}, mod::Module)
  slots = Dict{Symbol, Any}()
  func_def[:name] = gensym()
  func_def[:args] = (func_def[:args]..., func_def[:kwargs]...)
  func_def[:kwargs] = []
  # replace yield with inference barrier
  func_def[:body] = postwalk(transform_yield, func_def[:body])
  # collect items to skip
  nosaves = Set{Symbol}()
  func_def[:body] = postwalk(x->transform_nosave(x, nosaves), func_def[:body])
  # eval function
  func_expr = combinedef(func_def) |> flatten
  @eval(mod, @noinline $func_expr)
  # get typed code
  codeinfos = @eval(mod, code_typed($(func_def[:name]), Tuple; optimize=false))
  # extract slot names and types
  for codeinfo in codeinfos
    for (name, type) in collect(zip(codeinfo.first.slotnames, codeinfo.first.slottypes))
      name ∉ nosaves && name ∉ unused && (slots[name] = Union{type, get(slots, name, Union{})})
    end
  end
  # remove `catch exc` statements
  postwalk(x->remove_catch_exc(x, slots), func_def[:body])
  # set error branches to Any
  for (key, val) in slots
    if val === Union{}
      slots[key] = Any
    end
  end
  return func_def[:name], slots
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

# this is similar to code_typed but it considers the world age
function code_typed_by_type(@nospecialize(tt::Type);
                            optimize::Bool=true,
                            world::UInt=Base.get_world_counter(),
                            interp::Core.Compiler.AbstractInterpreter=Core.Compiler.NativeInterpreter(world))
    tt = Base.to_tuple_type(tt)
    # look up the method
    match, valid_worlds = Core.Compiler.findsup(tt, Core.Compiler.InternalMethodTable(world))
    # run inference, normally not allowed in generated functions
    frame = Core.Compiler.typeinf_frame(interp, match.method, match.spec_types, match.sparams, optimize)
    frame === nothing && error("inference failed")
    valid_worlds = Core.Compiler.intersect(valid_worlds, frame.valid_worlds)
    return frame.linfo, frame.src, valid_worlds
end

function fsmi_generator(world::UInt, source::LineNumberNode, passtype, fsmitype::Type{Type{T}}, fargtypes) where T
    @nospecialize
    # get typed code of the inference function evaluated in get_slots
    # but this time with concrete argument types
    tt = Base.to_tuple_type(fargtypes)
    mi, ci, valid_worlds = try
      code_typed_by_type(tt; world, optimize=false)
    catch err # inference failed, return generic type
      @safe_warn "Inference of a @resumable function failed -- a slower fallback will be used and everything will still work, however please consider reporting this to the developers of ResumableFunctions.jl so that we can debug and increase performance"
      @safe_warn "The error was $err"
      slots = fieldtypes(T)[2:end]
      stub = Core.GeneratedFunctionStub(identity, Core.svec(:pass, :fsmi, :fargs), Core.svec())
      if isempty(slots)
        return stub(world, source, :(return $T()))
      else
        return stub(world, source, :(return $T{$(slots...)}()))
      end
    end
    min_world = valid_worlds.min_world
    max_world = valid_worlds.max_world
    # extract slot types
    cislots = Dict{Symbol, Any}()
    for (name, type) in collect(zip(ci.slotnames, ci.slottypes))
      # take care to widen types that are unstable or Const
      type = Core.Compiler.widenconst(type)
      cislots[name] = Union{type, get(cislots, name, Union{})}
    end
    slots = map(slot->get(cislots, slot, Any), fieldnames(T)[2:end])
    # generate code to instantiate the concrete type
    stub = Core.GeneratedFunctionStub(identity, Core.svec(:pass, :fsmi, :fargs), Core.svec())
    if isempty(slots)
      exprs = stub(world, source, :(return $T()))
    else
      exprs = stub(world, source, :(return $T{$(slots...)}()))
    end
    # lower codeinfo to pass world age and invalidation edges
    ci = ccall(:jl_expand_and_resolve, Any, (Any, Any, Any), exprs, passtype.name.module, Core.svec())
    ci.min_world = min_world
    ci.max_world = max_world
    ci.edges = Core.MethodInstance[mi]
    if isdefined(Base, :__has_internal_change) && Base.__has_internal_change(v"1.12-alpha", :codeinfonargs) # due to julia#54341
      ci.nargs = 3
      ci.isva = true
    end
    return ci
end

# JuliaLang/julia#48611: world age is exposed to generated functions, and should be used
if VERSION >= v"1.10.0-DEV.873"
  # This is like @generated, but it receives the world age of the caller
  # which we need to do inference safely and correctly
  @eval function typed_fsmi(fsmi, fargs...)
      $(Expr(:meta, :generated_only))
      $(Expr(:meta, :generated, fsmi_generator))
  end
else
  # runtime fallback function that uses the fallback constructor with generic slot types
  function typed_fsmi(fsmi::Type{T}, fargs...)::T where T
    return typed_fsmi_fallback(fsmi, fargs...)
  end
end

# a fallback function that uses the fallback constructor with generic slot types -- useful for older versions of Julia or for situations where our current custom inference struggles
function typed_fsmi_fallback(fsmi::Type{T}, fargs...)::T where T
  return T()
end

mutable struct ScopeTracker
  i::Int
  mod::Module
  scope_stack::Vector
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
  new = Symbol(s, Symbol("_$(S.i)"))
  S.i += 1
  D[s] = new
  return new
end

function lookup_lhs!(s::QuoteNode, S::ScopeTracker)
  return s
end

function lookup_lhs!(s::Expr, S::ScopeTracker)
  if s.head === :(.)
    s.args[1] === lookup_lhs!(s.args[1], S)
    return s
  end
  @assert s.head === :tuple
  for i in 1:length(s.args)
    s.args[i] = lookup_rhs!(s.args[i], S)
  end
  return s
end

function lookup_rhs!(s::Symbol, S::ScopeTracker)
  for D in Iterators.reverse(S.scope_stack)
    if haskey(D, s)
      return D[s]
    end
  end
  return s
end

function lookup!(s::Symbol, S::ScopeTracker; new = false)
  s == :val && @show s, length(S.scope_stack), new
  if isdefined(S.mod, s)
    return s
  end
  if !new
    for D in Iterators.reverse(S.scope_stack)
      if haskey(D, s)
        return D[s]
      end
    end
    D = last(S.scope_stack)
    D[s] = s
    return s
  end
  D = last(S.scope_stack)
  new = Symbol(s, Symbol("_$(S.i)"))
  S.i += 1
  D[s] = new
  return new
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

function scoping(s::Symbol, scope; new = false)
  #@info "scoping $s, $new"
  return lookup_rhs!(s, scope)
end

function scoping(expr::Expr, scope)
  if expr.head === :comprehension
    # this is again special with respect to scoping
    if expr.args[1].head === :generator
      # first the generator case
      for i in 2:length(expr.args[1].args)
        @assert expr.args[1].args[i] isa Expr && expr.args[1].args[i].head === :(=)
        expr.args[1].args[i].args[2] = lookup_rhs!(expr.args[1].args[i].args[2], scope)
      end
      # now create new scope
      push!(scope.scope_stack, Dict())
      for i in 2:length(expr.args[1].args)
        expr.args[1].args[i].args[1] = lookup_lhs!(expr.args[1].args[i].args[1], scope)
      end

      expr.args[1].args[1] = scoping(expr.args[1].args[1], scope)
      pop!(scope.scope_stack)
      return expr
    else
      error("not implemented yet")
    end
  end

  if expr.head === :(=)
    if expr.args[1] isa Symbol
      expr.args[1] = lookup_lhs!(expr.args[1], scope)
    else
      for i in 1:length(expr.args[1].args)
        expr.args[1].args[i] = lookup_lhs!(expr.args[1].args[i], scope)
      end
    end
    for i in 2:length(expr.args)
      expr.args[i] = scoping(expr.args[i], scope)
    end
    return expr
  end
  if expr.head === :macrocall
    for i in 2:length(expr.args)
      expr.args[i] = scoping(expr.args[i], scope)
    end
    return expr
  end
  new_stack = false
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
    #   :(

    # defer adding a new scope after the right hand side have been renamed
    @capture(expr, let arg_; body_ end) || return expr
    @capture(arg, begin x__ end)
    replace_rhs = []
    for i in 1:length(x)
      y = x[i]
      fl = @capture(y, k_ = v_)
      if fl
        push!(replace_rhs, scoping(v, scope))
      else
        # there was no right side
        push!(replace_rhs, nothing)
      end
    end
    new_stack = true
    push!(scope.scope_stack, Dict())
    replace_lhs = []
    rep = []
    for i in 1:length(x)
      y = x[i]
      fl = @capture(y, k_ = v_)
      if fl
        push!(replace_lhs, lookup_lhs!(k, scope, new = true))
        push!(rep, quote local $(replace_lhs[i]); $(replace_lhs[i]) = $(replace_rhs[i]) end)
      else
        @assert y isa Symbol
        push!(replace_lhs, lookup_lhs!(y, scope, new = true))
        push!(rep, quote local $(replace_lhs[i]) end)
      end
    end
    rep = quote
      $(rep...)
    end
    rep = MacroTools.flatten(rep)
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

  if expr.head === :while || expr.head === :let
    push!(scope.scope_stack, Dict())
    new_stack = true
  end
  if expr.head === :local
    # this is my local dance
    # explain and rewrite using @capture
    #
    # if I see a local x or local x = ...
    # we always emit a new identifier
    if length(expr.args) == 1 && expr.args[1] isa Symbol
      #expr.args[1] = scoping(expr.args[1], scope, new = true)
      expr.args[1] = lookup_lhs!(expr.args[1], scope)
    elseif length(expr.args) == 1 && expr.args[1].head === :tuple
      for i in 1:length(expr.args[1].args)
        a = expr.args[1].args[i]
        #expr.args[1].args[i] = scoping(a, scope, new = true)
        expr.args[1].args[i] = lookup_lhs!(a, scope)
      end
    else
      for i in 1:length(expr.args)
        a = expr.args[i]
        #expr.args[i] = scoping(a, scope, new = true)
        expr.args[i] = lookup_lhs!(a, scope)
      end
    end
  else
    for i in 1:length(expr.args)
      a = expr.args[i]
      expr.args[i] = scoping(a, scope)
    end
  end
  if new_stack
    pop!(scope.scope_stack)
  end
  return expr
end
