using MacroTools

function transform_slots(expr, symbols::Base.KeyIterator{Dict{Symbol,Type}})
  @capture(expr, sym_ | sym_.inner_) || return expr
  sym isa Symbol && sym in symbols || return expr
  inner == nothing ? :(_fsmi.$sym) : :(_fsmi.$sym.$inner)
end

function transform_for(expr)
  @capture(expr, for element_ in iterator_ body__ end) || return expr
  iter = gensym()
  state = gensym()
  quote 
    $iter = $iterator
    $state = start($iter)
    while !done($iter, $state)
      $element, $state = next(_fsmi.$iter, $state)
      $(body...)
    end
  end
end

function transform_arg(expr)
  @capture(expr, arg_ = @yield ret_) || return expr
  quote
    @yield $ret
    _ret isa Exception && throw(_ret)
    $arg = _ret
  end
end

function transform_try(expr)
  @capture(expr, try body__ catch exc_ handling__ end) || return expr
  new_body = []
  segment = []
  for ex in body
    if @capture(ex, (@yield ret_))
      push!(new_body, quote
          try 
            $(segment...) 
          catch $exc
            $(handling...) 
          end
        end)
      push!(new_body, quote @yield $ret end)
      segment = []
    else
      push!(segment, ex)
    end
  end
  if segment != []
    push!(new_body, quote
        try 
          $(segment...) 
        catch $exc
          $(handling...) 
        end
      end)
  end
  quote $(new_body...) end
end

function transform_yield(expr)

end