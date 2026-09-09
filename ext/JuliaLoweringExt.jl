"""
Scope resolution backed by JuliaLowering.jl.

`@resumable` needs to know which binding every identifier in a function body refers to, so that
each distinct local gets its own field on the state machine. That knowledge currently comes from a
reimplementation of Julia's scope rules inside this package. Here it comes from JuliaLowering, which
is the compiler's own implementation of those rules.

Only the first three lowering passes are run. The fourth and fifth rewrite the body into closures
and linear IR, which discards the structure the state machine is built from.
"""
module JuliaLoweringExt

using ResumableFunctions: ResumableFunctions, Binding
using JuliaLowering: SyntaxTree, expr_to_syntaxtree, expand_forms_1, expand_forms_2,
                     resolve_scopes, lookup_binding
using JuliaSyntax: @K_str, kind, is_leaf, children

function ResumableFunctions.resolve_bindings(mod::Module, ex)
  tree = ex isa SyntaxTree ? ex : expr_to_syntaxtree(ex)
  ctx1, ex1 = expand_forms_1(mod, tree, false, Base.get_world_counter())
  ctx2, ex2 = expand_forms_2(ctx1, ex1)
  ctx3, ex3 = resolve_scopes(ctx2, ex2)
  ctx3, ex3, collect_bindings(ctx3, ex3)
end

function collect_bindings(ctx, ex, acc = Dict{Int,Binding}())
  if kind(ex) === K"BindingId"
    info = lookup_binding(ctx, ex.var_id)
    acc[info.id] = Binding(info.id, Symbol(info.name), info.kind, info.n_assigned,
                           info.is_captured, info.is_always_defined)
  end
  if !is_leaf(ex)
    for child in children(ex)
      collect_bindings(ctx, child, acc)
    end
  end
  acc
end

function ResumableFunctions.bindings_named(bindings::Dict{Int,Binding}, name::Symbol)
  sort!([b for b in values(bindings) if b.name === name]; by = b -> b.id)
end

end
