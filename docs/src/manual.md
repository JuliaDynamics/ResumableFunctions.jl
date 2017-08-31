# Manual

## Basic usage

When a `@resumable function` is called, it continues where it left during the previous invocation:

```jldoctest
julia> @resumable function basic_example()
  @yield "Initial call"
  @yield "Second call"
  "Final call"
end;

julia> basic_example()
Initial call

julia> basic_example()
Second call

julia> basic_example()
Final call
```