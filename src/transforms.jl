using MacroTools

function transform_slots(expr, symbols::Base.KeyIterator{Dict{Symbol,Type}})
  @capture(expr, sym_ | sym_.inner_) || return expr
  sym isa Symbol && sym in symbols || return expr
  inner == nothing ? :(_fsmi.$sym) : :(_fsmi.$sym.$inner)
end

function transform_for(expr, ui8::BoxedUInt8)
  @capture(expr, for element_ in iterator_ body__ end) || return expr
  ui8.n += one(UInt8)
  iter = Symbol("_iterator_", ui8.n)
  state = Symbol("_iterstate_", ui8.n)
  quote 
    $iter = $iterator
    $state = start($iter)
    while !done($iter, $state)
      $element, $state = next($iter, $state)
      $(body...)
    end
  end
end

function transform_arg(expr)
  @capture(expr, arg_ = @yield ret_) || return expr
  quote
    @yield $ret
    $arg = _arg
  end
end

function transform_exc(expr)
  @capture(expr, @yield ret_) || return expr
  quote
    @yield $ret
    _arg isa Exception && throw(_arg)
  end
end

function transform_try(expr)
  @capture(expr, try body__ catch exc_ handling__ end) || return expr
  new_body = []
  segment = []
  for ex in body
    if @capture(ex, (@yield ret_))
      push!(new_body, :(try $(segment...) catch $exc; $(handling...) end))
      push!(new_body, quote @yield $ret end)
      segment = []
    else
      push!(segment, ex)
    end
  end
  if segment != []
    push!(new_body, :(try $(segment...) catch $exc; $(handling...) end))
  end
  quote $(new_body...) end
end

function transform_yield(expr, ui8::BoxedUInt8)
  @capture(expr, @yield ret_) || return expr
  ui8.n += one(UInt8)
  quote
    _fsmi._state = $(ui8.n)
    return $ret
    @label $(Symbol("_STATE_",:($(ui8.n))))
    _fsmi._state = 0xff
  end
end