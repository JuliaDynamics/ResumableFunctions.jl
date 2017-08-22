using MacroTools: postwalk, striplines, flatten, unresolve, resyntax

macro yield(expr=nothing)
  esc(expr)
end

macro resumable(expr::Expr)
  expr.head != :function && error("Expression is not a function definition!")
  func_def = splitdef(expr)
  args = [(begin (a, b, c, d) = splitarg(arg); :($a) end for arg in func_def[:args])...,
          (begin (a, b, c, d) = splitarg(arg); :($a) end for arg in func_def[:kwargs])...]
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_for(x, ui8), func_def[:body])
  slots = getslots(copy(func_def))
  type_name = gensym()
  type_expr = quote
    mutable struct $type_name <: ResumableFunctions.FiniteStateMachineIterator
      _state :: UInt8
      $((:($slotname :: $(slottype == Union{} ? Any : :($slottype))) for (slotname, slottype) in slots)...)
      function $type_name($(func_def[:args]...);$(func_def[:kwargs]...))
        fsmi = new()
        fsmi._state = 0x00
        $((:(fsmi.$arg = $arg) for arg in args)...)
        fsmi
      end
    end
  end
  type_expr = type_expr |> striplines |> flatten |> unresolve |> resyntax
  #println(type_expr)
  call_def = copy(func_def)
  call_def[:name] = func_def[:name]
  call_def[:rtype] = type_name
  call_def[:body] = :($type_name($((:($arg) for arg in args)...)))
  call_expr = combinedef(call_def) |> striplines |> flatten |> unresolve |> resyntax
  #println(call_expr)
  func_def[:name] = :((_fsmi::$type_name))
  func_def[:body] = postwalk(x->transform_slots(x, keys(slots)), func_def[:body])
  func_def[:body] = postwalk(transform_arg, func_def[:body]) |> flatten
  func_def[:body] = postwalk(transform_exc, func_def[:body]) |> flatten
  func_def[:body] = postwalk(transform_try, func_def[:body]) |> flatten
  ui8 = BoxedUInt8(zero(UInt8))
  func_def[:body] = postwalk(x->transform_yield(x, ui8), func_def[:body])
  func_def[:body] = quote
    _fsmi._state == 0x00 && @goto _STATE_0
    $((:(_fsmi._state == $i && @goto $(Symbol("_STATE_",:($i)))) for i in 0x01:ui8.n)...)
    error("Iterator has stopped!")
    @label _STATE_0
    _fsmi._state = 0xff
    $(func_def[:body])
  end
  func_def[:args] = [combinearg(:_arg, Any, false, :nothing)]
  func_expr = combinedef(func_def) |> striplines |> flatten |> unresolve |> resyntax
  #println(func_expr)
  esc(:($type_expr; $func_expr; $call_expr))
end
