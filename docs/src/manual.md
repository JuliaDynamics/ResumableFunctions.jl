# Manual

## Basic usage

When a `@resumable function` is called, it continues where it left during the previous invocation:

```@meta
DocTestSetup = quote
  using ResumableFunctions
  
  @resumable function basic_example()
    @yield "Initial call"
    @yield "Second call"
    "Final call"
  end
end
```

```julia
@resumable function basic_example()
  @yield "Initial call"
  @yield "Second call"
  "Final call"
end
```

```jldoctest
julia> basic_iterator = basic_example();

julia> basic_iterator()
"Initial call"

julia> basic_iterator()
"Second call"

julia> basic_iterator()
"Final call"
```

```@meta
DocTestSetup = nothing
```