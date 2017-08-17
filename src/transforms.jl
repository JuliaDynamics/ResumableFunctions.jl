using MacroTools

function transform_for(expr)
  @capture(expr, for element_ in iterator_ body__ end) || return expr
  iter = gensym()
  state = gensym()
  quote 
    $iter = $iterator
    $state = start($iter)
    while !done($iter, $state)
      $element, $state = next($iter, $state)
      $(body...)
    end
  end
end

function transform_vars(expr)

end

function transform_try(expr)

end

function transform_yield(expr)

end