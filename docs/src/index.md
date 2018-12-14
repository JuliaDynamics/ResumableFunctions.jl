# ResumableFunctions

C# sharp style generators a.k.a. semi-coroutines for Julia.

C# has a convenient way to create iterators using the `yield return` statement. The package `ResumableFunctions` provides the same functionality for the Julia language by introducing the `@resumable` and the `@yield` macros. These macros can be used to replace the `Task` switching functions `produce` and `consume` which were deprecated in Julia v0.6. `Channels` are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications.

## Example

```jldoctest
using ResumableFunctions

@resumable function fibonnaci(n::Int)
  a = 0
  b = 1
  for i in 1:n
    @yield a
    a, b = b, a+b
  end
end

for val in fibonnaci(10) 
  println(val) 
end

# output

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

## Installation

`ResumableFunctions` is a registered package and can be installed by running:
```julia
Pkg.add("ResumableFunctions")
```

## Authors

* Ben Lauwens, Royal Military Academy, Brussels, Belgium.

## License

`ResumableFunctions` is licensed under the MIT "Expat" License.
