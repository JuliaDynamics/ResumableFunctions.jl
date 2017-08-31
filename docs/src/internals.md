# Internals

The macro `@resumable` transform a function definition into a finite state-machine, i.e. a callable type holding the state and references to the internal variables of the function and a constructor for this new type respecting the method signature of the original function definition. When calling the new type a modified version of the body of the original function definition is executed:
  - a dispatch mechanism is inserted at the start to allow a non local jump to a label inside the body;
  - the `@yield` statement is replaced by a `return` statement and a label placeholder as endpoint of a non local jump;
  - `for` loops are transformed in `while` loops and
  - `try`-`catch`-`finally`-`end` expressions are converted in a sequence of `try`-`catch`-`end` expressions with at the end of the `catch` part a non local jump to a label that marks the beginning of the expressions in the `finally` part.
The two last transformations are needed to overcome the limitations of the non local jump macros `@goto` and `@label`.

The complete procedure is explained using the following example:

```julia
@resumable function fibonnaci(n::Int)
  a = 0
  b = 1
  for i in 1:n-1
    @yield a
    a, b = b, a + b
  end
  a
end
```

## Split the definition

The function definition is split by `MacroTools.splitdef` in different parts, eg. `:name`, `:body`, `:args`, ...

## For loops

`for` loops in the body of the function definition are transformed in equivalent while loops:

```julia
begin
  a = 0
  b = 1
  _iter = 1:n-1
  _iterstate = start(_iter)
  while !done(_iter, _iterstate)
    i, _iterstate = next(_iter, _iterstate)
    @yield a
    a, b = b, a + b
  end
  a
end
```

## Slots

The slots and their types in the function definition are recovered by running the `code_typed` function for the locally evaluated function definition:

```julia
n :: Int64
a :: Int64
b :: Int64
_iter :: UnitRange{Int64}
_iterstate :: Int64
i :: Int64
```

## Type definition

A `mutable struct` is defined containing the state and the slots:

```julia
mutable struct ##123 <: ResumableFunctions.FiniteStateMachineIterator
      _state :: UInt8
      n :: Int64
      a :: Int64
      b :: Int64
      _iter :: UnitRange{Int64}
      _iterstate :: Int64
      i :: Int64 

      function ##123(n::Int64)
        fsmi = new()
        fsmi._state = 0x00
        fsmi.n = n
        fsmi
      end
    end
```

## Call definition

A call function is constructed that creates the previously defined composite type. This function satisfy the calling convention of the original function definition and is returned from the macro:

```julia
function fibonnaci(n::Int)
  ##123(n)
end
```

## Transformation of the body

In 6 steps the body of the function definition is transformed into a finite state-machine.

### Renaming of slots

The slots are replaced by references to the fields of the composite type:

```julia
begin
  _fsmi.a = 0
  _fsmi.b = 1
  _fsmi._iter = 1:n-1
  _fsmi._iterstate = start(_fsmi._iter)
  while !done(_fsmi._iter, _fsmi._iterstate)
    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)
    @yield _fsmi.a
    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b
  end
  _fsmi.a
end
```

### Two-way communication

All expressions of the form `_fsmi.arg = @yield` are transformed into:

```julia
@yield
_fsmi.arg = _arg
```

### Exception handling

Exception handling is added to `@yield`:

```julia
begin
  _fsmi.a = 0
  _fsmi.b = 1
  _fsmi._iter = 1:n-1
  _fsmi._iterstate = start(_fsmi._iter)
  while !done(_fsmi._iter, _fsmi._iterstate)
    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)
    @yield _fsmi.a
    _arg isa Exception && throw(_arg)
    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b
  end
  _fsmi.a
end
```

### Try catch finally end block handling

`try`-`catch`-`finally`-`end` expressions are converted in a sequence of `try`-`catch`-`end` expressions with at the end of the `catch` part a non local jump to a label that marks the beginning of the expressions in the `finally` part.

### Yield transformation

The `@yield` statement is replaced by a `return` statement and a label placeholder as endpoint of a non local jump:

```julia
begin
  _fsmi.a = 0
  _fsmi.b = 1
  _fsmi._iter = 1:n-1
  _fsmi._iterstate = start(_fsmi._iter)
  while !done(_fsmi._iter, _fsmi._iterstate)
    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)
    _fsmi._state = 0x01
    return _fsmi.a
    @label _STATE_1
    _fsmi._state = 0xff
    _arg isa Exception && throw(_arg)
    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b
  end
  _fsmi.a
end
```

### Dispatch mechanism

A dispatch mechanism is inserted at the start of the body to allow a non local jump to a label inside the body:

```julia
begin
  _fsmi_state == 0x00 && @goto _STATE_0
  _fsmi_state == 0x01 && @goto _STATE_1
  error("@resumable function has stopped!")
  @label _STATE_0
  _fsmi._state = 0xff
  _arg isa Exception && throw(_arg)
  _fsmi.a = 0
  _fsmi.b = 1
  _fsmi._iter = 1:n-1
  _fsmi._iterstate = start(_fsmi._iter)
  while !done(_fsmi._iter, _fsmi._iterstate)
    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)
    _fsmi._state = 0x01
    return _fsmi.a
    @label _STATE_1
    _fsmi._state = 0xff
    _arg isa Exception && throw(_arg)
    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b
  end
  _fsmi.a
end
```

## Making the type callable

A function is defined with one argument `_arg`:

```julia
function (_fsmi::##123)(_arg::Any=nothing)
  _fsmi_state == 0x00 && @goto _STATE_0
  _fsmi_state == 0x01 && @goto _STATE_1
  error("@resumable function has stopped!")
  @label _STATE_0
  _fsmi._state = 0xff
  _arg isa Exception && throw(_arg)
  _fsmi.a = 0
  _fsmi.b = 1
  _fsmi._iter = 1:n-1
  _fsmi._iterstate = start(_fsmi._iter)
  while !done(_fsmi._iter, _fsmi._iterstate)
    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)
    _fsmi._state = 0x01
    return _fsmi.a
    @label _STATE_1
    _fsmi._state = 0xff
    _arg isa Exception && throw(_arg)
    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b
  end
  _fsmi.a
end
```