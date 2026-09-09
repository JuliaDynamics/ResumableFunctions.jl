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

"""
Stand-ins for `@yield`, `@yieldfrom` and `@nosave` while a body is lowered.

JuliaLowering expands macros in its first pass, and these three throw when expanded outside a
`@resumable` function, which is what makes them useful as errors elsewhere. So they are replaced
by calls to these functions before lowering, and looked for again afterwards. The functions are
never called; `@resumable` rewrites them away.
"""
function yield_marker end
function yieldfrom_marker end
function nosave_marker end

const _MARKERS = Dict(Symbol("@yield")     => :yield_marker,
                      Symbol("@yieldfrom") => :yieldfrom_marker,
                      Symbol("@nosave")    => :nosave_marker)

"""
    substitute_markers(ex)

Replace the `@yield`, `@yieldfrom` and `@nosave` macro calls in `ex` with calls to the marker
functions above, so that they survive macro expansion.

`@nosave var = rhs` becomes `var = nosave_marker(rhs)` rather than a call wrapping the whole
assignment, which would turn the binding into a keyword argument and lose it.
"""
substitute_markers(ex) = ex

function substitute_markers(ex::Expr)
  args = Any[substitute_markers(a) for a in ex.args]
  ex.head === :macrocall || return Expr(ex.head, args...)
  marker = get(_MARKERS, args[1], nothing)
  marker === nothing && return Expr(ex.head, args...)
  call_args = filter(a -> !(a isa LineNumberNode), args[2:end])
  ref = GlobalRef(@__MODULE__, marker)
  if marker === :nosave_marker
    length(call_args) == 1 && Meta.isexpr(call_args[1], :(=), 2) || return Expr(ex.head, args...)
    var, rhs = call_args[1].args
    return Expr(:(=), var, Expr(:call, ref, rhs))
  end
  Expr(:call, ref, call_args...)
end

"""
    slot_bindings(mod, ex)

The bindings of `ex` that need storage on the state machine, grouped by source name.

Globals need no slot, and neither do the temporaries lowering introduces. A name maps to more
than one binding when it is bound in more than one scope, and each of those needs its own slot.

Implemented by the JuliaLowering extension.
"""
function slot_bindings end
