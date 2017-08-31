# Manual

## Basic usage

When a `@resumable function` is called, it continues where it left during the previous invocation:

```jldoctest
julia> @resumable function basic_example()
  @yield "Initial call"
  @yield "Second call"
  "Final call"
end;

julia> basic_iterator = basic_example();

julia> basic_iterator()
"Initial call"

julia> basic_iterator()
"Second call"

julia> basic_iterator()
"Final call"
```