# Semicoroutines

C# style generators a.k.a. semi-coroutines for Julia.

C# has a convenient way to create iterators using the `yield return` statement. The package `Semicoroutines` provides the same functionality for the Julia language by introducing the `@resumable` and the `@yield` macros. These macros can be used to replace the `Task` switching functions `produce` and `consume` which were deprecated in Julia v0.6. `Channels` are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications.

```jldoctest
using Semicoroutines

@resumable function fibonacci(n::Int)
  a = 0
  b = 1
  for i in 1:n
    @yield a
    a, b = b, a+b
  end
end

for val in fibonacci(10) 
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

`Semicoroutines.jl` is a fork Ben Lauwens' of `ResumableFunctions.jl`.