# ResumableFunctions

C# sharp style generators a.k.a. semi-coroutines for Julia.

C# has a convenient way to create iterators [@C#Iterators] using the `yield return` statement. The package `ResumableFunctions` provides the same functionality for the Julia language by introducing the `@resumable` and the `@yield` macros. These macros can be used to replace the `Task` switching functions `produce` and `consume` which were deprecated in Julia v0.6. `Channels` are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications.

## Example

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

## Installation

`ResumableFunctions` is a registered package and can be installed by running:
```julia
Pkg.add("ResumableFunctions")
```

## Authors

* Ben Lauwens, Royal Military Academy, Brussels, Belgium.

## License

`ResumableFunctions` licensed under the MIT "Expat" License.
