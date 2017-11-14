"""
Macro if used in a `@resumable function` that returns the `expr` otherwise returns `:nothing`.
"""
macro yield(expr=nothing)
  esc(:nothing)
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
  args = get_args(func_def)
  params = ((get_param_name(param) for param in func_def[:whereparams])...)
  #println(params)
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_for(x, ui8), func_def[:body]) |> flatten
  mod = VERSION >= v"0.7.0-" ? __module__ : current_module()
  slots = get_slots(copy(func_def), mod, args)
  #println(func_def)
  #println(slots)
  type_name = gensym()
  if isempty(params)
    type_expr = quote
      mutable struct $type_name <: ResumableFunctions.FiniteStateMachineIterator
        _state :: UInt8
        $((:($slotname :: $slottype) for (slotname, slottype) in slots)...)
        function $type_name($(func_def[:args]...),$(func_def[:kwargs]...))
          fsmi = new()
          fsmi._state = 0x00
          $((:(fsmi.$arg = $arg) for arg in keys(args))...)
          fsmi
        end
      end
    end
  else
    type_expr = quote
      mutable struct $type_name{$(func_def[:whereparams]...)} <: ResumableFunctions.FiniteStateMachineIterator
        _state :: UInt8
        $((:($slotname :: $slottype) for (slotname, slottype) in slots)...)
        function $type_name{$(params...)}($(func_def[:args]...),$(func_def[:kwargs]...)) where $(func_def[:whereparams]...)
          fsmi = new()
          fsmi._state = 0x00
          $((:(fsmi.$arg = $arg) for arg in keys(args))...)
          fsmi
        end
      end
    end
  end
  #println(type_expr)
  call_def = copy(func_def)
  if isempty(params)
    call_def[:rtype] = :($type_name)
    call_def[:body] = :($type_name($((:($arg) for arg in keys(args))...)))
  else
    call_def[:rtype] = :($type_name{$(params...)})
    call_def[:body] = :($type_name{$(params...)}($((:($arg) for arg in keys(args))...)))
  end
  call_expr = combinedef(call_def) |> flatten
  #println(call_expr)
  func_def[:kwargs] = []
  if isempty(params)
    func_def[:name] = :((_fsmi::$type_name))
  else
    func_def[:name] = :((_fsmi::$type_name{$(params...)}))
  end
  func_def[:body] = postwalk(x->transform_slots(x, keys(slots)), func_def[:body])
  func_def[:body] = postwalk(transform_arg, func_def[:body]) |> flatten
  func_def[:body] = postwalk(transform_exc, func_def[:body]) |> flatten
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_try(x, ui8), func_def[:body]) |> flatten
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_yield(x, ui8), func_def[:body]) |> flatten
  func_def[:body] = quote
    _fsmi._state == 0x00 && @goto _STATE_0
    $((:(_fsmi._state == $i && @goto $(Symbol("_STATE_",:($i)))) for i in 0x01:ui8.n)...)
    error("@resumable function has stopped!")
    @label _STATE_0
    _fsmi._state = 0xff
    _arg isa Exception && throw(_arg)
    $(func_def[:body])
  end
  func_def[:args] = [Expr(:kw, :(_arg::Any), nothing)]
  func_expr = combinedef(func_def) 
  #println(func_expr)
  esc(:($type_expr; $func_expr; $call_expr))
end
