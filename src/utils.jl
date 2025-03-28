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
  inferfn = @eval(mod, @noinline $func_expr)
  #@info func_def[:body]|>MacroTools.striplines
  # get typed code
  codeinfos = Core.eval(mod, code_typed(inferfn, Tuple; optimize=false))
  #@info codeinfos
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
  return inferfn, slots
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
    @static if VERSION >= v"1.12.0-DEV.1552"
      valid_worlds = Core.Compiler.intersect(frame.world, valid_worlds).valid_worlds
    else
      valid_worlds = Core.Compiler.intersect(valid_worlds, frame.valid_worlds)
    end
    return frame.linfo, frame.src, valid_worlds
end

function fsmi_generator(world::UInt, source, passtype, fsmitype::Type{Type{T}}, fargtypes) where T
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
      return stub(world, source, :(return $T()))
    else
      return stub(world, source, :(return $T{$(slots...)}()))
    end
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

function scope_generator(expr, scope)
  expr.head !== :generator && error("Illegal generator expression: $(expr)")
  # first the generator case
  for i in 2:length(expr.args)
    !(expr.args[i] isa Expr && expr.args[i].head === :(=)) && error("Illegal expression in generator: $(expr.args[i])")
    expr.args[i].args[2] = scoping(expr.args[i].args[2], scope)
  end
  # now create new scope
  push!(scope.scope_stack, Dict())
  for i in 2:length(expr.args)
    expr.args[i].args[1] = lookup_lhs!(expr.args[i].args[1], scope, new = true)
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
            error("Uncregonized expression in tuple expression: $(expr.args[i])")
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
  if expr.head === :generator
    expr = scope_generator(expr)
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
    #   Thus we add a new scope, resolve the RHS and force the LHS to be new.
    #   Do this one after the other and everything will be fine.

    @capture(expr, let arg_; body_ end) || return expr
    @capture(arg, begin x__ end)
    new_stack = true
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
