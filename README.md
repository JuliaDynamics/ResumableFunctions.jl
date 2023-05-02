# Semicoroutines

<table>
    <tr>
        <td>Documentation</td>
        <td>
            <a href="https://quantumsavory.github.io/Semicoroutines.jl/stable"><img src="https://img.shields.io/badge/docs-stable-blue.svg" alt="Documentation of latest stable version"></a>
            <a href="https://quantumsavory.github.io/Semicoroutines.jl/dev"><img src="https://img.shields.io/badge/docs-dev-blue.svg" alt="Documentation of dev version"></a>
        </td>
    </tr><tr></tr>
    <tr>
        <td>Continuous integration</td>
        <td>
            <a href="https://github.com/QuantumSavory/Semicoroutines.jl/actions?query=workflow%3ACI+branch%3Amaster"><img src="https://img.shields.io/github/actions/workflow/status/QuantumSavory/Semicoroutines.jl/ci.yml?branch=master" alt="GitHub Workflow Status"></a>
        </td>
    </tr><tr></tr>
    <tr>
        <td>Code coverage</td>
        <td>
            <a href="https://codecov.io/gh/QuantumSavory/Semicoroutines.jl"><img src="https://img.shields.io/codecov/c/gh/QuantumSavory/Semicoroutines.jl?label=codecov" alt="Test coverage from codecov"></a>
        </td>
    </tr><tr></tr>
    <tr>
        <td>Static analysis with</td>
        <td>
            <a href="https://github.com/aviatesk/JET.jl"><img src="https://img.shields.io/badge/JET.jl-%E2%9C%88%EF%B8%8F-9cf" alt="JET static analysis"></a>
            <a href="https://github.com/JuliaTesting/Aqua.jl"><img src="https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg" alt="Aqua QA"></a>
        </td>
    </tr>
</table>

[C#](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/) has a convenient way to create iterators using the `yield return` statement. The package `Semicoroutines` provides the same functionality for the [Julia language](https://julialang.org) by introducing the `@resumable` and the `@yield` macros. These macros can be used to replace the `Task` switching functions `produce` and `consume` which were deprecated in Julia v0.6. `Channels` are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications. See [the benchmarks section below](#Benchmarks).

`Semicoroutines.jl` is a fork Ben Lauwens' of `ResumableFunctions.jl`.

```julia
using Semicoroutines

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

## Caveats

* In a `try` block only top level `@yield` statements are allowed.
* In a `finally` block a `@yield` statement is not allowed.
* An anonymous function can not contain a `@yield` statement.
