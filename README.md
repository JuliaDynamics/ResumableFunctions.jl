# ResumableFunctions

C# has a convenient way to create iterators [@C#Iterators] using the `yield return` statement. The package `ResumableFunctions` provides the same functionality for the Julia language by introducing the `@resumable` and the `@yield` macros. These macros can be used to replace the `Task` switching functions `produce` and `consume` which were deprecated in Julia v0.6. `Channels` are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications.

#### Build Status

[![Build Status](https://travis-ci.org/BenLauwens/ResumableFunctions.jl.svg?branch=master)](https://travis-ci.org/BenLauwens/ResumableFunctions.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/6vm5y0w5q0uwgv7v/branch/master?svg=true)](https://ci.appveyor.com/project/BenLauwens/resumablefunctions-jl/branch/master)

#### Coverage

[![Coverage Status](https://coveralls.io/repos/github/BenLauwens/ResumableFunctions.jl/badge.svg?branch=master)](https://coveralls.io/github/BenLauwens/ResumableFunctions.jl?branch=master)
[![codecov.io](http://codecov.io/github/benlauwens/ResumableFunctions.jl/coverage.svg?branch=master)](http://codecov.io/github/benlauwens/ResumableFunctions.jl?branch=master)

#### Installation

`ResumableFunctions` is not yet registered but can be installed by running:
```julia
Pkg.clone("https://github.com/BenLauwens/ResumableFunctions.jl.git")
```

#### Example

```julia
using ResumableFunctions

@resumable function fibonnaci(n::Int) :: Int
  a = 0
  b = 1
  for i in 1:n-1
    @yield a
    a, b = b, a+b
  end
  a
end

for fib in fibonnaci(10)
  println(fib)
end
```

#### Documentation

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://benlauwens.github.io/ResumableFunctions.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://benlauwens.github.io/ResumableFunctions.jl/latest)

#### Release Notes

* This is pre-release software. 
* Tests and documentation are a work in progress.
* Comments and bug reports are greatly appreciated!
* Two-way communication is allowed between master and slave function:
```julia
arg = @yield ret
```
* `#yield` statements in a `try`-`catch`-`finally`-`end` expression are allowed in the `try` part (only top level statements) and the `catch` part:
```julia
try
  @yield
catch
  @yield
end
```

#### Authors

* Ben Lauwens, Royal Military Academy, Brussels, Belgium

#### License

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)
