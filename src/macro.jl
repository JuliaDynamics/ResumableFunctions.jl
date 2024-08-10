"""
Macro if used in a `@resumable function` that returns the `expr` otherwise throws an error.
"""
macro yield(expr=nothing)
  error("@yield macro outside a @resumable function!")
end

"""
Macro if used in a `@resumable function` that delegates to `expr` otherwise throws an error.
"""
macro yieldfrom(expr=nothing)
  error("@yieldfrom macro outside a @resumable function!")
end

"""
Macro if used in a `@resumable function` that creates a not saved variable otherwise throws an error.
"""
macro nosave(expr=nothing)
  error("@nosave macro outside a @resumable function!")
end

"""
Macro that transforms a function definition in a finite-state machine:

- Defines a new `mutable struct` that implements the iterator interface and is used to store the internal state.
- Makes this new type callable having following characteristics:
  - implementents the statements from the initial function definition but;
  - returns at a `@yield` statement and;
  - continues after the `@yield` statement when called again.
- Defines a constructor function that respects the calling conventions of the initial function definition and returns an object of the new type.

If the element type and length is known, the resulting iterator can be made
more efficient as follows:
- Use `length=ex` to specify the length (if known) of the iterator, like:
    @resumable length=ex function f(x); body; end
  Here `ex` can be any expression containing the arguments of `f`.
- Use `function f(x)::T` to specify the element type of the iterator.

# Extended

```julia
julia> @resumable length=n^2 function f(n)::Int
         for i in 1:n^2
           @yield i
         end
       end
f (generic function with 2 methods)

julia> collect(f(3))
9-element Vector{Int64}:
 1
 2
 3
 4
 5
 6
 7
 8
 9
```
"""
macro resumable(ex::Expr...)
  length(ex) >= 3 && error("Too many arguments")
  for i in 1:length(ex)-1
    a = ex[i]
    if !(a isa Expr && a.head === :(=) && a.args[1] in [:length])
      error("only keyword argument 'length' allowed")
    end
  end

  expr = ex[end]
  expr.head !== :function && error("Expression is not a function definition!")

  # The function that executes a step of the finite state machine
  func_def = splitdef(expr)
  @debug func_def[:body]
  rtype = :rtype in keys(func_def) ? func_def[:rtype] : Any
  args, kwargs, arg_dict = get_args(func_def)
  params = ((get_param_name(param) for param in func_def[:whereparams])...,)

  # Initial preparation of the function stepping through the finite state machine and extraction of local variables and their types
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(transform_arg_yieldfrom, func_def[:body])
  func_def[:body] = postwalk(transform_yieldfrom, func_def[:body])
  func_def[:body] = postwalk(x->transform_for(x, ui8), func_def[:body])
  @debug func_def[:body]|>MacroTools.striplines
  #func_def[:body] = postwalk(x->transform_macro(x), func_def[:body])
  #@debug func_def[:body]|>MacroTools.striplines
  #func_def[:body] = postwalk(x->transform_macro_undo(x), func_def[:body])
  #@debug func_def[:body]|>MacroTools.striplines
  #func_def[:body] = postwalk(x->transform_let(x), func_def[:body])
  #@info func_def[:body]|>MacroTools.striplines
  #func_def[:body] = postwalk(x->transform_local(x), func_def[:body])
  # Scoping fixes

  # :name is :(fA::A) if it is an overloading call function (fA::A)(...)
  # ...
  if func_def[:name] isa Expr
    @assert func_def[:name].head == :(::)
    _name = func_def[:name].args[1]
  else
    _name = func_def[:name]
  end
  
  scope = ScopeTracker(0, __module__, [Dict(i =>i for i in vcat(args, kwargs, [_name], params...))])
  #@info func_def[:body]|>MacroTools.striplines
  #@info func_def[:body]|>MacroTools.striplines
  func_def[:body] = scoping(copy(func_def[:body]), scope)
  #@info func_def[:body]|>MacroTools.striplines
  func_def[:body] = postwalk(x->transform_remove_local(x), func_def[:body])
  @info func_def[:body]|>MacroTools.striplines

  inferfn, slots = get_slots(copy(func_def), arg_dict, __module__)
  @debug slots

  # check if the resumable function is a callable struct instance (a functional) that is referencing itself
  isfunctional = @capture(func_def[:name], functional_::T_) && inexpr(func_def[:body], functional)
  if isfunctional
    slots[functional] = T
    push!(args, functional)
  end

  # The finite state machine structure definition
  type_name = gensym(Symbol(func_def[:name], :_FSMI))
  constr_def = copy(func_def)
  slot_T = [gensym(s) for s in keys(slots)]
  slot_T_sub = [:($k <: $v) for (k, v) in zip(slot_T, values(slots))]
  struct_name = :($type_name{$(func_def[:whereparams]...), $(slot_T_sub...)} <: ResumableFunctions.FiniteStateMachineIterator{$rtype})
  constr_def[:whereparams] = (func_def[:whereparams]..., slot_T_sub...)

  # if there are no where or slot type parameters, we need to use the bare type
  if isempty(params) && isempty(slot_T)
    constr_def[:name] = :($type_name)
  else
    constr_def[:name] = :($type_name{$(params...), $(slot_T...)})
  end
  constr_def[:args] = tuple()
  constr_def[:kwargs] = tuple()
  constr_def[:rtype] = nothing
  constr_def[:body] = quote
    fsmi = new()
    fsmi._state = 0x00
    fsmi
  end
  # the bare/fallback version of the constructor supplies default slot type parameters
  # we only need to define this if there there are actually slot defaults to be filled
  if !isempty(slot_T)
    bareconstr_def = copy(constr_def)
    if isempty(params)
      bareconstr_def[:name] = :($type_name)
    else
      bareconstr_def[:name] = :($type_name{$(params...)})
    end
    bareconstr_def[:whereparams] = func_def[:whereparams]
    bareconstr_def[:body] = :($(bareconstr_def[:name]){$(values(slots)...)}())
    bareconst_expr = combinedef(bareconstr_def) |> flatten
  else
    bareconst_expr = nothing
  end
  constr_expr = combinedef(constr_def) |> flatten
  type_expr = :(
    mutable struct $struct_name
      _state :: UInt8
      $((:($slotname :: $slottype) for (slotname, slottype) in zip(keys(slots), slot_T))...)
      $(constr_expr)
      $(bareconst_expr)
    end
  )
  @debug type_expr|>MacroTools.striplines
  # The "original" function that now is simply a wrapper around the construction of the finite state machine
  call_def = copy(func_def)
  call_def[:rtype] = nothing
  if isempty(params)
    fsmi_name = type_name
  else
    fsmi_name = :($type_name{$(params...)})
  end
  fwd_args, fwd_kwargs = forward_args(call_def)
  isfunctional && push!(fwd_args, functional)
  call_def[:body] = quote
    fsmi = ResumableFunctions.typed_fsmi($fsmi_name, $inferfn, $(fwd_args...), $(fwd_kwargs...))
    $((arg !== Symbol("_") ? :(fsmi.$arg = $arg) : nothing for arg in args)...)
    $((:(fsmi.$arg = $arg) for arg in kwargs)...)
    fsmi
  end
  call_expr = combinedef(call_def) |> flatten
  @debug call_expr|>MacroTools.striplines
  
  # Finalizing the function stepping through the finite state machine
  if isempty(params)
    func_def[:name] = :((_fsmi::$type_name))
  else
    func_def[:name] = :((_fsmi::$type_name{$(params...)}))
  end
  func_def[:rtype] = nothing
  func_def[:body] = postwalk(x->transform_slots(x, keys(slots)), func_def[:body])

  # Capture the length=...
  interface_defs = []
  for i in 1:length(ex)-1
    a = ex[i]
    if !(a isa Expr && a.head === :(=) && a.args[1] in [:length])
      error("only keyword argument 'length' allowed")
    end
    if a.args[1] === :length
      push!(interface_defs, quote Base.IteratorSize(::Type{<: $type_name}) = Base.HasLength() end)
      func_def2 = copy(func_def)
      func_def2[:body] = a.args[2]
      new_body = postwalk(x->transform_slots(x, keys(slots)), a.args[2])
      push!(interface_defs, quote Base.length(_fsmi::$type_name) = begin $new_body end end)
    end
  end

  func_def[:body] = postwalk(transform_arg, func_def[:body])
  func_def[:body] = postwalk(transform_exc, func_def[:body]) |> flatten
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_try(x, ui8), func_def[:body])
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_yield(x, ui8), func_def[:body])
  func_def[:body] = postwalk(x->transform_nosave(x, Set{Symbol}()), func_def[:body])
  func_def[:body] = quote
    _fsmi._state === 0x00 && @goto $(Symbol("_STATE_0"))
    $((:(_fsmi._state === $i && @goto $(Symbol("_STATE_",:($i)))) for i in 0x01:ui8.n)...)
    error("@resumable function has stopped!")
    @label $(Symbol("_STATE_0"))
    _fsmi._state = 0xff
    _arg isa Exception && throw(_arg)
    $(func_def[:body])
  end
  func_def[:args] = [Expr(:kw, :(_arg::Any), nothing)]
  func_def[:kwargs] = []
  func_expr = combinedef(func_def) |> flatten

  if inexpr(func_def[:body], call_def[:name]) || isfunctional
    @debug "recursion or self-reference is present in a resumable function definition: falling back to no inference"
    call_expr = postwalk(x->x==:(ResumableFunctions.typed_fsmi) ? :(ResumableFunctions.typed_fsmi_fallback) : x, call_expr)
  end
  @debug func_expr|>MacroTools.striplines
  # The final expression:
  # - the finite state machine struct
  # - the function stepping through the states
  # - the "original" function which now is a simple wrapper around the construction of the finite state machine
  esc(quote
    $type_expr
    $func_expr
    $(interface_defs...)
    Base.@__doc__($call_expr)
  end)
end
