# ResumableFunctions

[C#](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/) has a convenient way to create iterators using the `yield return` statement. The package `ResumableFunctions` provides the same functionality for the [Julia language](https://julialang.org) by introducing the `@resumable` and the `@yield` macros. These macros can be used to replace the `Task` switching functions `produce` and `consume` which were deprecated in Julia v0.6. `Channels` are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications. See [the benchmarks section below](#Benchmarks).

## Build Status & Coverage

[![Build Status](https://github.com/benlauwens/ResumableFunctions.jl/workflows/CI/badge.svg)](https://github.com/benlauwens/ResumableFunctions.jl/actions?query=workflow%3ACI+branch%3Amaster)
[![codecov.io](http://codecov.io/github/benlauwens/ResumableFunctions.jl/coverage.svg?branch=master)](http://codecov.io/github/benlauwens/ResumableFunctions.jl?branch=master)

## Installation

`ResumableFunctions` is a [registered package](http://pkg.julialang.org) and can be installed by running:
```julia
using Pkg
Pkg.add("ResumableFunctions")
```

##  Documentation

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://benlauwens.github.io/ResumableFunctions.jl/v0.6.0-docs)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://benlauwens.github.io/ResumableFunctions.jl/dev)

```julia
using ResumableFunctions

@resumable function fibonacci(n::Int) :: Int
  a = 0
  b = 1
  for i in 1:n
    @yield a
    a, b = b, a+b
  end
end

for fib in fibonacci(10)
  println(fib)
end
```

## Benchmarks
The following block is the result of running `julia --project=. benchmark/benchmarks.jl` on a Macbook Pro with following processor: `Intel Core i9 2,4 GHz 8-Core`. Julia version 1.5.3 was used.

Fibonacci with `Int` values:

```
Direct: 
  27.184 ns (0 allocations: 0 bytes)
ResumableFunctions: 
  27.503 ns (0 allocations: 0 bytes)
Channels csize=0: 
  2.438 ms (101 allocations: 3.08 KiB)
Channels csize=1: 
  2.546 ms (23 allocations: 1.88 KiB)
Channels csize=20: 
  138.681 μs (26 allocations: 2.36 KiB)
Channels csize=100: 
  35.071 μs (28 allocations: 3.95 KiB)
Task scheduling
  17.726 μs (86 allocations: 3.31 KiB)
Closure: 
  1.948 μs (82 allocations: 1.28 KiB)
Closure optimised: 
  25.910 ns (0 allocations: 0 bytes)
Closure statemachine: 
  28.048 ns (0 allocations: 0 bytes)
Iteration protocol: 
  41.143 ns (0 allocations: 0 bytes)
```

Fibonacci with `BigInt` values:

```
Direct: 
  5.747 μs (188 allocations: 4.39 KiB)
ResumableFunctions: 
  5.984 μs (191 allocations: 4.50 KiB)
Channels csize=0: 
  2.508 ms (306 allocations: 7.75 KiB)
Channels csize=1: 
  2.629 ms (306 allocations: 7.77 KiB)
Channels csize=20: 
  150.274 μs (309 allocations: 8.25 KiB)
Channels csize=100: 
  44.592 μs (311 allocations: 9.84 KiB)
Task scheduling
  24.802 μs (198 allocations: 6.61 KiB)
Closure: 
  7.064 μs (192 allocations: 4.47 KiB)
Closure optimised: 
  5.809 μs (190 allocations: 4.44 KiB)
Closure statemachine: 
  5.826 μs (190 allocations: 4.44 KiB)
Iteration protocol: 
  5.822 μs (190 allocations: 4.44 KiB)
```

## Licence & References

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
[![status](http://joss.theoj.org/papers/889b2faed426b978ee705689c8f8440b/status.svg)](http://joss.theoj.org/papers/889b2faed426b978ee705689c8f8440b)
[![DOI](https://zenodo.org/badge/100050892.svg)](https://zenodo.org/badge/latestdoi/100050892)

## Authors

* Ben Lauwens, [Royal Military Academy](http://www.rma.ac.be), Brussels, Belgium.

## Contributing

* To discuss problems or feature requests, file an issue. For bugs, please include as much information as possible, including operating system, julia version, and version of [MacroTools](https://github.com/MikeInnes/MacroTools.jl.git).
* To contribute, make a pull request. Contributions should include tests for any new features/bug fixes.

## Release notes

* 2023: v0.6.2 
  * Julia v1.10 compatibility fix
  * resumable functions can now dispatch on types

* 2021: v0.6.1
  * `continu` in loop works

* 2021: v0.6.0
  * introduction of `@nosave` to keep a variable out of the saved structure.
  * optimized `for` loop.

* 2020: v0.5.2 is Julia v1.6 compatible.

* 2019: v0.5.1
  * inference problem solved: force iterator next value to be of type `Union` of `Tuple` and `Nothing`.

* 2019: v0.5.0 is Julia v1.2 compatible.

* 2018: v0.4.2 prepare for Julia v1.1
  * better inference caused a problem;).
  * iterator with a specified `rtype` is fixed.

* 2018: v0.4.0 is Julia v1.0 compatible.

* 2018: v0.3.1 uses the new iteration protocol.
  * the new iteration protocol is used for a `@resumable function` based iterator.
  * the `for` loop transformation implements also the new iteration protocol.

* 2018: v0.3 is Julia v0.7 compatible.
  * introduction of `let` block to allow variables not te be persisted between `@resumable function` calls (EXPERIMENTAL).
  * the `eltype` of a `@resumable function` based iterator is its return type if specified, otherwise `Any`.

* 2018: v0.2 the iterator now behaves as a Python generator: only values that are explicitely yielded are generated; the return value is ignored and a warning is generated.

* 2017: v0.1 initial release that is Julia v0.6 compatible:
  * Introduction of the `@resumable` and the `@yield` macros.
  * A `@resumable function` generates a type that implements the [iterator](https://docs.julialang.org/en/stable/manual/interfaces/#man-interface-iteration-1) interface.
  * Parametric `@resumable functions` are supported.

## Caveats

* In a `try` block only top level `@yield` statements are allowed.
* In a `finally` block a `@yield` statement is not allowed.
* An anonymous function can not contain a `@yield` statement.
