"""
One binding of a resolved function body.

`n_assigned` and `is_captured` together say whether Julia boxes the variable: a local that is
captured by an inner function and assigned more than once becomes a `Core.Box`. `is_always_defined`
is false for a local that can be read before it is written, which is how a body like `a = a` reads.
"""
struct Binding
  id                :: Int
  name              :: Symbol
  kind              :: Symbol
  n_assigned        :: Int
  is_captured       :: Bool
  is_always_defined :: Bool
end

is_boxed(b::Binding) = b.is_captured && b.n_assigned > 1

"""
    resolve_bindings(mod, ex)

Resolve the bindings of the function definition `ex` as `mod` would see it, and return the
lowering context, the resolved syntax tree, and a `Dict` of [`Binding`](@ref) keyed by binding id.

Implemented by the JuliaLowering extension, so JuliaLowering.jl has to be loaded to call it.
"""
function resolve_bindings end

"""
    bindings_named(bindings, name)

The bindings called `name`, in id order. More than one means the name is bound in more than one
scope, as in `a = 1; let a = 2; end`.
"""
function bindings_named end
