# ResumableFunctions


<table>
    <tr>
        <td>Documentation</td>
        <td>
            <a href="https://juliadynamics.github.io/ResumableFunctions.jl/stable"><img src="https://img.shields.io/badge/docs-stable-blue.svg" alt="Documentation of latest stable version"></a>
            <a href="https://juliadynamics.github.io/ResumableFunctions.jl/dev"><img src="https://img.shields.io/badge/docs-dev-blue.svg" alt="Documentation of dev version"></a>
        </td>
    </tr><tr></tr>
    <tr>
        <td>Continuous integration</td>
        <td>
            <a href="https://github.com/JuliaDynamics/ResumableFunctions.jl/actions?query=workflow%3ACI+branch%3Amaster"><img src="https://img.shields.io/github/actions/workflow/status/JuliaDynamics/ResumableFunctions.jl/ci.yml?branch=master" alt="GitHub Workflow Status"></a>
        </td>
    </tr><tr></tr>
    <tr>
        <td>Code coverage</td>
        <td>
            <a href="https://codecov.io/gh/JuliaDynamics/ResumableFunctions.jl"><img src="https://img.shields.io/codecov/c/gh/JuliaDynamics/ResumableFunctions.jl?label=codecov" alt="Test coverage from codecov"></a>
        </td>
    </tr><tr></tr>
    <tr>
        <td>Static analysis with</td>
        <td>
            <a href="https://github.com/aviatesk/JET.jl"><img src="https://img.shields.io/badge/%F0%9F%9B%A9%EF%B8%8F_tested_with-JET.jl-233f9a" alt="JET static analysis"></a>
            <a href="https://github.com/JuliaTesting/Aqua.jl"><img src="https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg" alt="Aqua QA"></a>
        </td>
    </tr>
</table>

[![status](http://joss.theoj.org/papers/889b2faed426b978ee705689c8f8440b/status.svg)](http://joss.theoj.org/papers/889b2faed426b978ee705689c8f8440b)
[![DOI](https://zenodo.org/badge/100050892.svg)](https://zenodo.org/badge/latestdoi/100050892)

[C#](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/) has a convenient way to create iterators using the `yield return` statement. The package `ResumableFunctions` provides the same functionality for the [Julia language](https://julialang.org) by introducing the `@resumable` and the `@yield` macros. These macros can be used to replace the `Task` switching functions `produce` and `consume` which were deprecated in Julia v0.6. `Channels` are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications. See [the benchmarks section below](#Benchmarks).

## Installation

`ResumableFunctions` is a [registered package](http://pkg.julialang.org) and can be installed by running:
```julia
using Pkg
Pkg.add("ResumableFunctions")
```

##  Example

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
The following block is the result of running `julia --project=. benchmark/benchmarks.jl` on a Macbook Pro with following processor: `Intel Core i9 2.4 GHz 8-Core`. Julia version 1.5.3 was used.

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

## Authors

* Ben Lauwens, [Royal Military Academy](http://www.rma.ac.be), Brussels, Belgium.
* JuliaDynamics and QuantumSavory volunteers.

## Contributing

* To discuss problems or feature requests, file an issue. For bugs, please include as much information as possible, including operating system, julia version, and version of [MacroTools](https://github.com/MikeInnes/MacroTools.jl.git).
* To contribute, make a pull request. Contributions should include tests for any new features/bug fixes.

## Release Notes

A [detailed change log is kept](https://github.com/JuliaDynamics/ResumableFunctions.jl/blob/master/CHANGELOG.md).

## Caveats

* In a `try` block only top level `@yield` statements are allowed.
* In a `finally` block a `@yield` statement is not allowed.
* An anonymous function can not contain a `@yield` statement.
* Many more restrictions.
