# Manual

## Basic usage

When a `@resumable function` is called, it continues where it left during the previous invocation:

```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function basic_example()
    @yield "Initial call"
    @yield "Second call"
    "Final call"
  end
end
```

```julia
@resumable function basic_example()
  @yield "Initial call"
  @yield "Second call"
  "Final call"
end
```

```jldoctest
julia> basic_iterator = basic_example();

julia> basic_iterator()
"Initial call"

julia> basic_iterator()
"Second call"

julia> basic_iterator()
"Final call"
```

```@meta
DocTestSetup = nothing
```

The `@yield` can also be used without a return argument:

```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function basic_example()
    @yield "Initial call"
    @yield 
    "Final call"
  end
end
```

```julia
@resumable function basic_example()
  @yield "Initial call"
  @yield 
  "Final call"
end
```

```jldoctest
julia> basic_iterator = basic_example();

julia> basic_iterator()
"Initial call"

julia> basic_iterator()

julia> basic_iterator()
"Final call"
```

```@meta
DocTestSetup = nothing
```

The famous Fibonnaci sequence can easily be generated:
```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function fibonnaci()
    a = 0
    b = 1
    while true
      @yield a
      a, b = b, a + b
    end
  end
end
```

```julia
@resumable function fibonnaci()
  a = 0
  b = 1
  while true
    @yield a
    a, b = b, a + b
  end
end
```

```jldoctest
julia> fib_iterator = fibonnaci();

julia> fib_iterator()
0

julia> fib_iterator()
1

julia> fib_iterator()
1

julia> fib_iterator()
2

julia> fib_iterator()
3

julia> fib_iterator()
5

julia> fib_iterator()
8
```

```@meta
DocTestSetup = nothing
```

The `@resumable function` can take arguments and the type of the return value can be specified:

```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function fibonnaci(n) :: Int
    a = 0
    b = 1
    for i in 1:n-1
      @yield a
      a, b = b, a + b
    end
    a
  end
end
```

```julia
@resumable function fibonnaci(n) :: Int
  a = 0
  b = 1
  for i in 1:n-1
    @yield a
    a, b = b, a + b
  end
  a
end
```

```jldoctest
julia> fib_iterator = fibonnaci(4);

julia> fib_iterator()
0

julia> fib_iterator()
1

julia> fib_iterator()
1

julia> fib_iterator()
2

julia> fib_iterator()
ERROR: @resumable function has stopped!
```

```@meta
DocTestSetup = nothing
```

If the `@resumable function` returns normally and error will be thrown if called again.

## Two-way communication

The caller can transmit a variable to the `@resumable function` by assigning a `@yield` statement to a variable:

```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function two_way()
    name = @yield "Who are you?"
    "Hello, " * name * "!"
  end
end
```

```julia
@resumable function two_way()
  name = @yield "Who are you?"
  "Hello, " * name * "!"
end
```

```jldoctest
julia> hello = two_way();

julia> hello()
"Who are you?"

julia> hello("Ben")
"Hello, Ben!
```

```@meta
DocTestSetup = nothing
```

When an `Exception` is passed to the `@resumable function`, it is thrown at the resume point: