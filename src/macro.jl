"""
Macro if used in a `@resumable function` that returns the `expr` otherwise throws an error.
"""
macro yield(expr=nothing)
  error("@yield macro outside a @resumable function!")
end

"""
Macro that transforms a function definition in a finite-statemachine:

- Defines a new `mutable struct` that implements the iterator interface and is used to store the internal state.
- Makes this new type callable having following characteristics:
  - implementents the statements from the initial function definition but;
  - returns at a `@yield` statement and;
  - continues after the `@yield` statement when called again.
- Defines a constructor function that respects the calling conventions of the initial function definition and returns an object of the new type.
"""
macro resumable(expr::Expr)
  expr.head != :function && error("Expression is not a function definition!")
  func_def = splitdef(expr)
  rtype = :rtype in keys(func_def) ? func_def[:rtype] : Any
  args, kwargs, arg_dict = get_args(func_def)
  #println(arg_dict)
  params = ((get_param_name(param) for param in func_def[:whereparams])...,)
  #println(params)
  ui8 = BoxedUInt8(zero(UInt8))
  postwalk(x->hasreturnvalue(x), func_def[:body])
  func_def[:body] = postwalk(x->transform_for(x, ui8), func_def[:body])
  slots = get_slots(copy(func_def), arg_dict, __module__)
  #println(slots)
  type_name = gensym()
  constr_def = copy(func_def)
  if isempty(params)
    struct_name = :($type_name <: ResumableFunctions.FiniteStateMachineIterator{$rtype})
    constr_def[:name] = :($type_name)
  else
    struct_name = :($type_name{$(func_def[:whereparams]...)} <: ResumableFunctions.FiniteStateMachineIterator{$rtype})
    constr_def[:name] = :($type_name{$(params...)})
  end
  constr_def[:args] = (func_def[:args]..., )
  #constr_def[:args] = make_args(func_def)
  constr_def[:kwargs] = (func_def[:kwargs]..., )
  constr_def[:rtype] = constr_def[:name]
  constr_def[:body] = quote
    fsmi = new()
    fsmi._state = 0x00
    $((:(fsmi.$arg = $arg) for arg in args)...)
    $((:(fsmi.$arg = $arg) for arg in kwargs)...)
    fsmi
  end
  constr_expr = combinedef(constr_def) |> flatten
  #println(constr_expr)
  type_expr = :(
    mutable struct $struct_name
      _state :: UInt8
      $((:($slotname :: $slottype) for (slotname, slottype) in slots)...)
      #$((:($slotname) for (slotname, slottype) in slots)...)
      $(constr_expr)
    end
  )
  #println(type_expr|>MacroTools.striplines)
  call_def = copy(func_def)
  if isempty(params)
    call_def[:rtype] = :($type_name)
    call_def[:body] = :($type_name($((:($arg) for arg in args)...); $((:($arg = $arg) for arg in kwargs)...)))
  else
    call_def[:rtype] = :($type_name{$(params...)})
    call_def[:body] = :($type_name{$(params...)}($((:($arg) for arg in args)...); $((:($arg = $arg) for arg in kwargs)...)))
  end
  call_expr = combinedef(call_def) |> flatten
  #println(call_expr|>MacroTools.striplines)
  if isempty(params)
    func_def[:name] = :((_fsmi::$type_name))
  else
    func_def[:name] = :((_fsmi::$type_name{$(params...)}))
  end
  func_def[:rtype] = :(Union{$rtype, Nothing, Bool})
  func_def[:body] = postwalk(x->transform_slots(x, keys(slots)), func_def[:body])
  func_def[:body] = postwalk(transform_arg, func_def[:body])
  func_def[:body] = postwalk(transform_exc, func_def[:body]) |> flatten
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_try(x, ui8), func_def[:body])
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_yield(x, ui8), func_def[:body])
  func_def[:body] = quote
    _fsmi._state == 0x00 && @goto $(Symbol("_STATE_0"))
    $((:(_fsmi._state == $i && @goto $(Symbol("_STATE_",:($i)))) for i in 0x01:ui8.n)...)
    error("@resumable function has stopped!")
    @label $(Symbol("_STATE_0"))
    _fsmi._state = 0xff
    _arg isa Exception && throw(_arg)
    $(func_def[:body])
  end
  func_def[:args] = [Expr(:kw, :(_arg::Any), nothing)]
  func_def[:kwargs] = []
  func_expr = combinedef(func_def) |> flatten
  #println(func_expr|>MacroTools.striplines)
  esc(:($type_expr; $func_expr; $call_expr))
end
