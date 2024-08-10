function transform_remove_local(ex)
  ex isa Expr && ex.head === :local && return Expr(:block)
  return ex
end

function transform_macro(ex)
  ex isa Expr || return ex
  ex.head !== :macrocall && return ex
  return Expr(:call, :__secret__, ex.args)
end

function transform_macro_undo(ex)
  ex isa Expr || return ex
  (ex.head !== :call || ex.args[1] !== :__secret__) && return ex
  return Expr(:macrocall, ex.args[2]...)
end

"""
Function that replaces a variable
"""
function transform_nosave(expr, nosaves::Set{Symbol})
  @capture(expr, @nosave var_ = body_) || return expr
  push!(nosaves, var)
  :($var = $body)
end

"""
Function that replaces a `@yieldfrom iter` statement with
```julia
  _other_ = iter...
  _ret_ = generate(_other_, nothing)
  while !(_ret_ isa IteratorReturn)
    _value_, _state_ = _ret_
    _newvalue_ = @yield _value_
    _ret_ = generate(_other_, _newvalue_, _state_)
  end
  _
```
"""
function transform_yieldfrom(expr)
  _is_yieldfrom(expr) || return expr
  iter = expr.args[3:end]
  quote
    _other_ = $(iter...)
    _ret_ = $generate(_other_, nothing)
    while !(_ret_ isa $IteratorReturn)
      _value_, _state_ = _ret_
      _newvalue_ = @yield _value_
      _ret_ = $generate(_other_, _newvalue_, _state_)
    end
  end
end

"""
Function that replaces an `arg = @yieldfrom iter` statement by
```julia
  @yieldfrom iter
  arg = _ret_.value
```
"""
function transform_arg_yieldfrom(expr)
  @capture(expr, arg_ = ex_) || return expr
  _is_yieldfrom(ex) || return expr
  iter = ex.args[3:end]
  quote
    @yieldfrom $(iter...)
    $arg = _ret_.value
  end
end

"""
Function returning whether an expression is a `@yieldfrom` macro
"""
_is_yieldfrom(ex) = false

function _is_yieldfrom(ex::Expr)
  is_ = ex.head === :macrocall && ex.args[1] === Symbol("@yieldfrom")
  if is_ && length(ex.args) < 3
    error("@yieldfrom without arguments!")
  end
  return is_
end


"""
Function that replaces a `for` loop by a corresponding `while` loop saving explicitly the *iterator* and its *state*.

For loops of the form `for a, b, c; body; end` are denested.
"""
function transform_for(expr, ui8::BoxedUInt8)
  (expr isa Expr && expr.head === :for) || return expr
  # test for simple for a in b expression
  expr.args[1].head === :(=) && return transform_for_inner(expr, ui8)
  # must be a complicated iteration
  @assert expr.args[1].head === :block
  body = expr.args[2]
  # denest, starting at the back
  for a in reverse(expr.args[1].args)
    body = Expr(:for, a, body)
    # turn for into while loop
    body = transform_for_inner(body, ui8)
  end
  return body
end

function transform_for_inner(expr, ui8::BoxedUInt8)
  # turning for into while loops
  @capture(expr, for element_ in iterator_ body_ end) || return expr
  localelement = Expr(:local, element)
  ui8.n += one(UInt8)
  next = Symbol("_iteratornext_", ui8.n)
  state = Symbol("_iterstate_", ui8.n)
  iterator_value = Symbol("_iterator_", ui8.n)
  label = Symbol("_iteratorlabel_", ui8.n)
  body = postwalk(x->transform_continue(x, label), :(begin $(body) end))
  res = quote
    $iterator_value = $iterator
    @nosave $next = iterate($iterator_value)
    while $next !== nothing
      $localelement
      ($element, $state) = $next
      $body
      @label $label
      $next = iterate($iterator_value, $state)
    end
  end
  res
end


"""
Function that replaces a `continue` statement by a corresponding `@goto` with as label the correct location for the next iteration.
"""
function transform_continue(expr, label::Symbol)
  @capture(expr, continue) || return expr
  :(@goto $label)
end

"""
Function that replaces a variable `x` in an expression by `_fsmi.x` where `x` is a known slot.
"""
function transform_slots(expr, symbols)
  expr isa Expr || return expr
  #expr.head === :let && return transform_slots_let(expr, symbols)
  for i in 1:length(expr.args)
    expr.head === :kw && i === 1 && continue
    expr.head === Symbol("quote") && continue
    expr.args[i] = expr.args[i] isa Symbol && expr.args[i] in symbols ? :(_fsmi.$(expr.args[i])) : expr.args[i]
  end
  expr
end

#"""
#Function that handles `let` block
#"""
#function transform_slots_let(expr::Expr, symbols)
#  @capture(expr, let vars_; body_ end)
#  locals = Set{Symbol}()
#  (isa(vars, Expr) && vars.head==:(=))  || error("@resumable currently supports only single variable declarations in let blocks, i.e. only let blocks exactly of the form `let i=j; ...; end`. If you need multiple variables, please submit an issue on the issue tracker and consider contributing a patch.")
#  sym = vars.args[1].args[2].value
#  push!(locals, sym)
#  vars.args[1] = sym
#  body = postwalk(x->transform_let(x, locals), :(begin $(body) end))
#  :(let $vars; $body end)
#end

function transform_let(expr)
  expr isa Expr || return expr
  expr.head === :block && return expr
  #@info "inside transform let"
  @capture(expr, let arg_; body_; end) || return expr
  #@info "captured let"
  #arg |> dump
  #@info expr
  #@info arg
  #error("ASds")
  res = quote
    let
      local $arg
      $body
    end
  end
  #@info "emitting $res"
  res
  #expr.head === :. || return expr
  #expr = expr.args[2].value in symbols ? :($(expr.args[2].value)) : expr
end

"""
Function that replaces a variable `_fsmi.x` in an expression by `x` where `x` is a variable declared in a `let` block.
"""
function transform_local(expr)
  expr isa Expr || return expr
  @capture(expr, local arg_ = ex_) || return expr
  res = quote
    local $arg
    $arg = $ex
  end
  res
end

"""
Function that replaces a `arg = @yield ret` statement by
```julia
  @yield ret;
  arg = arg_
```
where `arg_` is the argument of the function containing the expression.
"""
function transform_arg(expr)
  @capture(expr, arg_ = ex_) || return expr
  _is_yield(ex) || return expr
  ret = length(ex.args) > 2 ? ex.args[3:end] : [nothing]
  quote
    @yield $(ret...)
    $arg = _arg
  end
end

"""
Function that replaces a `@yield ret` or `@yield` statement by
```julia
  @yield ret
  _arg isa Exception && throw(_arg)
```
to allow that an `Exception` can be thrown into a `@resumable function`.
"""
function transform_exc(expr)
  _is_yield(expr) || return expr
  ret = length(expr.args) > 2 ? expr.args[3:end] : [nothing]
  quote
    @yield $(ret...)
    _arg isa Exception && throw(_arg)
  end
end

"""
Function that replaces a `try`-`catch`-`finally`-`end` expression having a top level `@yield` statement in the `try` part
```julia
  try
    before_statements...
    @yield ret
    after_statements...
  catch exc
    catch_statements...
  finally
    finally_statements...
  end
```
with a sequence of `try`-`catch`-`end` expressions:
```julia
  try
    before_statements...
  catch
    catch_statements...
    @goto _TRY_n
  end
  @yield ret
  try
    after_statements...
  catch
    catch_statements...
  end
  @label _TRY_n
  finally_statements...
```
"""
function transform_try(expr, ui8::BoxedUInt8)
  @capture(expr, (try body_ catch exc_; handling_ end) | (try body_ catch exc_; handling_ finally always_ end)) || return expr
  ui8.n += one(UInt8)
  new_body = []
  segment = []
  for ex in body.args
    if _is_yield(ex)
      ret = length(ex.args) > 2 ? ex.args[3:end] : [nothing]
      exc === nothing ? push!(new_body, :(try $(segment...) catch; $(handling); @goto $(Symbol("_TRY_", :($(ui8.n)))) end)) : push!(new_body, :(try $(segment...) catch $exc; $(handling) ; @goto $(Symbol("_TRY_", :($(ui8.n)))) end))
      push!(new_body, quote @yield $(ret...) end)
      segment = []
    else
      push!(segment, ex)
    end
  end
  if segment != []
    exc === nothing ? push!(new_body, :(try $(segment...) catch; $(handling) end)) : push!(new_body, :(try $(segment...) catch $exc; $(handling) end))
  end
  push!(new_body, :(@label $(Symbol("_TRY_", :($(ui8.n))))))
  always === nothing || push!(new_body, quote $(always) end)
  quote $(new_body...) end
end

"""
Function that replaces a `@yield ret` or `@yield` statement with
```julia
  _fsmi._state = n
  return ret
  @label _STATE_n
  _fsmi._state = 0xff
```
"""
function transform_yield(expr, ui8::BoxedUInt8)
  _is_yield(expr) || return expr
  ret = length(expr.args) > 2 ? expr.args[3:end] : [nothing]
  ui8.n += one(UInt8)
  quote
    _fsmi._state = $(ui8.n)
    return $(ret...)
    @label $(Symbol("_STATE_", :($(ui8.n))))
    _fsmi._state = 0xff
  end
end

"""
Function that replaces a `@yield ret` or `@yield` statement with
```julia
  Base.inferencebarrier(ret)
```
This version is used for inference only.
It makes sure that `val = @yield ret` is inferred as `Any` rather than `typeof(ret)`.
"""
function transform_yield(expr)
  _is_yield(expr) || return expr
  ret = length(expr.args) > 2 ? expr.args[3:end] : [nothing]
  quote
    Base.inferencebarrier($(ret...))
  end
end

"""
Function returning whether an expression is a `@yield` macro
"""
_is_yield(ex) = false

function _is_yield(ex::Expr)
  ex.head === :macrocall && ex.args[1] === Symbol("@yield")
end
