# Manual

```@meta
DocTestSetup = quote
  using ResumableFunctions
end
```

## Basic usage

When a `@resumable function` is called, it continues where it left during the previous invocation:

```jldoctest basic-example; output=false
@resumable function basic_example()
  @yield "Initial call"
  @yield "Second call"
  "Final call"
end
# output
basic_example (generic function with 1 method)
```

```jldoctest basic-example
julia> basic_iterator = basic_example();

julia> basic_iterator()
"Initial call"

julia> basic_iterator()
"Second call"

julia> basic_iterator()
"Final call"
```

The `@yield` can also be used without a return argument:

```jldoctest yield-example; output=false
@resumable function yield_example()
  @yield "Initial call"
  @yield
  "Final call"
end
# output
yield_example (generic function with 1 method)
```

```jldoctest yield-example
julia> yield_iterator = yield_example();

julia> yield_iterator()
"Initial call"

julia> yield_iterator()

julia> yield_iterator()
"Final call"
```

The famous Fibonacci sequence can easily be generated:

```jldoctest fibonacci; output=false
@resumable function fibonacci()
  a = 0
  b = 1
  while true
    @yield a
    a, b = b, a + b
  end
end
# output
fibonacci (generic function with 1 method)
```

```jldoctest fibonacci
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

The `@resumable function` can take arguments and the type of the return value can be specified:

```jldoctest fibo-rettype; output=false
@resumable function fibonacci(n) :: Int
  a = 0
  b = 1
  for i in 1:n
    @yield a
    a, b = b, a + b
  end
end
# output
fibonacci (generic function with 1 method)
```

```jldoctest fibo-rettype
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

When the `@resumable function` returns normally (i.e. at the end of the function rather than at a `@yield` point), an error will be thrown if called again.

## Two-way communication

The caller can transmit a variable to the `@resumable function` by assigning a `@yield` statement to a variable:

```jldoctest two-way; output=false
@resumable function two_way()
  name = @yield "Who are you?"
  "Hello, " * name * "!"
end
# output
two_way (generic function with 1 method) 
```

```jldoctest two-way
julia> hello = two_way();

julia> hello()
"Who are you?"

julia> hello("Ben")
"Hello, Ben!"
```

When an `Exception` is passed to the `@resumable function`, it is thrown at the resume point:

```jldoctest exception-pass; output=false
@resumable function mouse()
  try
    @yield "Here I am!"
  catch exc
    return "You got me!"
  end
end

struct Cat <: Exception end
# output

```

```jldoctest exception-pass
julia> catch_me = mouse();

julia> catch_me()
"Here I am!"

julia> catch_me(Cat())
"You got me!"
```

## Iterator interface

The iterator interface is implemented for a `@resumable function`:

```jldoctest iterate; output=false
@resumable function fibonacci(n) :: Int
  a = 0
  b = 1
  for i in 1:n
    @yield a
    a, b = b, a + b
  end
end
# output
fibonacci (generic function with 1 method)
```

```jldoctest iterate
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

## Parametric `@resumable` functions

Type parameters can be specified with a normal Julia `where` clause:

```jldoctest parametric; output=false
@resumable function fibonacci(a::N, b::N=a+one(N)) :: N where {N<:Number}
  for i in 1:10
    @yield a
    a, b = b, a + b
   end
end
# output
fibonacci (generic function with 2 methods)
```

```jldoctest parametric
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

## Caveats

- In a `try` block only top level `@yield` statements are allowed.
- In a `catch` or a `finally` block a `@yield` statement is not allowed.
- An anonymous function can not contain a `@yield` statement.
- If a `FiniteStateMachineIterator` object is used in more than one `for` loop, only the `state` variable is reinitialised. A `@resumable function` that alters its arguments will use the modified values as initial parameters.
