# ResumableFunctions

[C#](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/) has a convenient way to create iterators using the `yield return` statement. The package `ResumableFunctions` provides the same functionality for the [Julia language](https://julialang.org) by introducing the `@resumable` and the `@yield` macros. These macros can be used to replace the `Task` switching functions `produce` and `consume` which were deprecated in Julia v0.6. `Channels` are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications. See [the benchmarks section below](#Benchmarks).

## Build Status & Coverage

[![Build Status](https://travis-ci.org/BenLauwens/ResumableFunctions.jl.svg?branch=master)](https://travis-ci.org/BenLauwens/ResumableFunctions.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/6vm5y0w5q0uwgv7v/branch/master?svg=true)](https://ci.appveyor.com/project/BenLauwens/resumablefunctions-jl/branch/master)
[![Coverage Status](https://coveralls.io/repos/github/BenLauwens/ResumableFunctions.jl/badge.svg?branch=master)](https://coveralls.io/github/BenLauwens/ResumableFunctions.jl?branch=master)
[![codecov.io](http://codecov.io/github/benlauwens/ResumableFunctions.jl/coverage.svg?branch=master)](http://codecov.io/github/benlauwens/ResumableFunctions.jl?branch=master)

## Installation

[![ResumableFunctions](http://pkg.julialang.org/badges/ResumableFunctions_0.6.svg)](http://pkg.julialang.org/detail/ResumableFunctions)
[![ResumableFunctions](http://pkg.julialang.org/badges/ResumableFunctions_0.7.svg)](http://pkg.julialang.org/detail/ResumableFunctions)
[![ResumableFunctions](http://pkg.julialang.org/badges/ResumableFunctions_1.0.svg)](http://pkg.julialang.org/detail/ResumableFunctions)

`ResumableFunctions` is a [registered package](http://pkg.julialang.org) and can be installed by running:
```julia
using Pkg
Pkg.add("ResumableFunctions")
```

##  Documentation

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://benlauwens.github.io/ResumableFunctions.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://benlauwens.github.io/ResumableFunctions.jl/latest)

```julia
using ResumableFunctions

@resumable function fibonnaci(n::Int) :: Int
  a = 0
  b = 1
  for i in 1:n
    @yield a
    a, b = b, a+b
  end
end

for fib in fibonnaci(10)
  println(fib)
end
```

## Benchmarks
The following block is the result of running `julia --project=. benchmark/benchmarks.jl` on a computer with the processor: `Intel(R) Core(TM) i5-5300U CPU @ 2.30GHz`. Julia version 1.1.1 was used.

```
Direct:
  49.724 ns (0 allocations: 0 bytes)
ResumableFunctions:
  10.230 μs (281 allocations: 8.83 KiB)
Channels csize=0:
  305.877 μs (465 allocations: 8.84 KiB)
Channels csize=1:
  504.438 μs (379 allocations: 7.33 KiB)
Channels csize=20:
  87.889 μs (206 allocations: 5.06 KiB)
Channels csize=100:
  67.911 μs (198 allocations: 6.44 KiB)
Closure:
  2.437 μs (83 allocations: 1.31 KiB)
Closure optimised:
  245.676 ns (3 allocations: 64 bytes)
Closure statemachine:
  40.149 ns (0 allocations: 0 bytes)
Iteration protocol:
  63.635 ns (0 allocations: 0 bytes)
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

* 2019: v0.5.1
  * inference problem solved: force iterator next value to be of type `Union` of `Tuple` and `Nothing`.

* 2019: v0.5.0 is Julia v1.2 compatible

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
