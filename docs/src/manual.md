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

The famous fibonacci sequence can easily be generated:
```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function fibonacci()
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
@resumable function fibonacci()
  a = 0
  b = 1
  while true
    @yield a
    a, b = b, a + b
  end
end
```

```jldoctest
julia> fib_iterator = fibonacci();

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

  @resumable function fibonacci(n) :: Int
    a = 0
    b = 1
    for i in 1:n
      @yield a
      a, b = b, a + b
    end
  end
end
```

```julia
@resumable function fibonacci(n) :: Int
  a = 0
  b = 1
  for i in 1:n
    @yield a
    a, b = b, a + b
  end
end
```

```jldoctest
julia> fib_iterator = fibonacci(4);

julia> fib_iterator()
0

julia> fib_iterator()
1

julia> fib_iterator()
1

julia> fib_iterator()
2

julia> fib_iterator()

julia> fib_iterator()
ERROR: @resumable function has stopped!
```

```@meta
DocTestSetup = nothing
```

When the `@resumable function` returns normally an error will be thrown if called again.

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
"Hello, Ben!"
```

```@meta
DocTestSetup = nothing
```

When an `Exception` is passed to the `@resumable function`, it is thrown at the resume point:

```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function mouse()
    try
      @yield "Here I am!"
    catch exc
      return "You got me!"
    end
  end

  struct Cat <: Exception end
end
```

```julia
@resumable function mouse()
  try
    @yield "Here I am!"
  catch exc
    return "You got me!"
  end
end

struct Cat <: Exception end
```

```jldoctest
julia> catch_me = mouse();

julia> catch_me()
"Here I am!"

julia> catch_me(Cat())
"You got me!"
```

```@meta
DocTestSetup = nothing
```

## Iterator interface

The iterator interface is implemented for a `@resumable function`:

```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function fibonacci(n) :: Int
    a = 0
    b = 1
    for i in 1:n
      @yield a
      a, b = b, a + b
    end
  end
end
```

```julia
@resumable function fibonacci(n) :: Int
  a = 0
  b = 1
  for i in 1:n
    @yield a
    a, b = b, a + b
  end
end
```

```jldoctest
julia> for val in fibonacci(10) println(val) end
0
1
1
2
3
5
8
13
21
34
```

```@meta
DocTestSetup = nothing
```

## Parametric `@resumable` functions

Type parameters can be specified with a `where` clause:

```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function fibonacci(a::N, b::N=a+one(N)) :: N where {N<:Number}
    for i in 1:10
      @yield a
      a, b = b, a + b
    end
  end
end
```

```julia
@resumable function fibonacci(a::N, b::N=a+one(N)) :: N where {N<:Number}
  for i in 1:10
    @yield a
    a, b = b, a + b
   end
end
```

```jldoctest
julia> for val in fibonacci(0.0) println(val) end
0.0
1.0
1.0
2.0
3.0
5.0
8.0
13.0
21.0
34.0
```

```@meta
DocTestSetup = nothing
```

## Let block

A `let` block allows a variable not to be saved in between calls to a `@resumable function`:

```@meta
DocTestSetup = quote
  using ResumableFunctions

  @resumable function arrays_of_tuples()
    for u in [[(1,2),(3,4)], [(5,6),(7,8)]]
      for i in 1:2
        local val
        let i=i
          val = [a[i] for a in u]
        end
        @yield val
      end
    end
  end
end
```

```julia
@resumable function arrays_of_tuples()
  for u in [[(1,2),(3,4)], [(5,6),(7,8)]]
    for i in 1:2
      let i=i
        val = [a[i] for a in u]
      end
      @yield val
    end
  end
end
```

```jldoctest
julia> for array in arrays_of_tuples() println(array) end
[1, 3]
[2, 4]
[5, 7]
[6, 8]
```

```@meta
DocTestSetup = nothing
```

## Caveats

- In a `try` block only top level `@yield` statements are allowed.
- In a `catch` or a `finally` block a `@yield` statement is not allowed.
- An anonymous function can not contain a `@yield` statement.
- If a `FiniteStateMachineIterator` object is used in more than one `for` loop, only the `state` variable is reinitialised. A `@resumable function` that alters its arguments will use the modified values as initial parameters.
