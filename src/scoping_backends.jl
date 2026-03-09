"""
Selects which scoping backend to use for `@resumable` macro expansion.

Currently supported values:
- `legacy` (default): use the existing `ScopeTracker` + `scoping(...)` pass.
- `julialowering`: reserved for the experimental JuliaLowering-based path.

The selector is intentionally environment-based for now so the package can keep
current behavior by default while allowing controlled experiments on dedicated
branches.
"""
function scoping_backend()
  backend = lowercase(get(ENV, "RESUMABLEFUNCTIONS_SCOPE_BACKEND", "legacy"))
  backend in ("legacy", "julialowering") || throw(ArgumentError(
    "Unsupported RESUMABLEFUNCTIONS_SCOPE_BACKEND=$(repr(backend)). Expected `legacy` or `julialowering`."
  ))
  return Symbol(backend)
end

function apply_scope_fixes(func_body, args, kwargs, name, params, mod::Module)
  backend = scoping_backend()
  backend === :legacy && return apply_scope_fixes_legacy(func_body, args, kwargs, name, params, mod)
  backend === :julialowering && return apply_scope_fixes_julialowering(func_body, args, kwargs, name, params, mod)
  error("Unreachable scoping backend: $backend")
end

function apply_scope_fixes_legacy(func_body, args, kwargs, name, params, mod::Module)
  scope = ScopeTracker(0, mod, [Dict(i => i for i in vcat(args, kwargs, [name], params...))])
  func_body = scoping(copy(func_body), scope)
  func_body = postwalk(x->transform_remove_local(x), func_body)
  return func_body
end

function apply_scope_fixes_julialowering(func_body, args, kwargs, name, params, mod::Module)
  throw(ArgumentError(
    "The `julialowering` scoping backend is not implemented yet on this branch. " *
    "Use `RESUMABLEFUNCTIONS_SCOPE_BACKEND=legacy` (default) or continue the experimental JuliaLowering integration work."
  ))
end
