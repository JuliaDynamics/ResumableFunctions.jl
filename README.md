# ResumableFunctions

`ResumableFunctions` is a Julia package providing C# sharp style generators a.k.a. semi-coroutines.
A `@resumable` function yielding values is transformed in a finite state-machine and the next function call will continue after the previous `@yield` statement.

#### Build Status

[![Build Status](https://travis-ci.org/BenLauwens/ResumableFunctions.jl.svg?branch=master)](https://travis-ci.org/BenLauwens/ResumableFunctions.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/6vm5y0w5q0uwgv7v/branch/master?svg=true)](https://ci.appveyor.com/project/BenLauwens/resumablefunctions-jl/branch/master)

#### Coverage

[![Coverage Status](https://coveralls.io/repos/github/BenLauwens/ResumableFunctions.jl/badge.svg?branch=master)](https://coveralls.io/github/BenLauwens/ResumableFunctions.jl?branch=master)
[![codecov.io](http://codecov.io/github/benlauwens/ResumableFunctions.jl/coverage.svg?branch=master)](http://codecov.io/github/benlauwens/ResumableFunctions.jl?branch=master)

#### Installation

`ResumableFunctions` is not yet registered but can be installed by running:
```julia
Pkg.clone(https://github.com/BenLauwens/ResumableFunctions.jl.git)
```

#### Release Notes

* This is pre-release software. 
* Tests and documentation are a work in progress.
* Comments and bug reports are greatly appreciated!

#### Authors

* Ben Lauwens, Royal Military Academy, Brussels, Belgium

#### License

[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md)