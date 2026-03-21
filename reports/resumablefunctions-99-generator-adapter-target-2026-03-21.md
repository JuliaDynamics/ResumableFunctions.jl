# ResumableFunctions #99 — First JuliaLowering Adapter Target

Date: 2026-03-21
Repo: `/root/.openclaw/workspace/repos/ResumableFunctions.jl`
Branch: `bounty-99-julialowering-scout`
Current proof commit: `0d11ada`

## Goal
Define the smallest explicit first adapter slice for `JuliaDynamics/ResumableFunctions.jl#99` based on proof work already completed in-repo.

This document is **not** the broad migration plan. It is the narrow contract for the first slice only.

## Chosen first slice
**Generator/filter cases only** where the current proof helpers already show semantic agreement after narrow normalization.

Representative proof case:

```julia
(i + x for i in 1:x if i < x)
```

with outer binding `x`.

## Why this slice
The current proof helpers show that this case is much closer than nested comprehensions.

By commit `a7fe469`, the branch has the following proof helpers available:

```julia
experimental_generator_filter_slice_supported(...)
experimental_generator_binding_comparison(...)
experimental_generator_binding_contract_met(...)
experimental_generator_filter_slice_status(...)
```

For the representative proof case,

```julia
experimental_generator_binding_comparison(
    "(i + x for i in 1:x if i < x)";
    outer_bindings=[:x],
)
```

returns the key stable signals:

- `manual_globalrefs = ["+", "x", "<", "x", ":", "x"]`
- `jl_globalrefs = ["+", "x", "<", "x", ":", "x"]`
- `globalrefs_match = true`
- `manual_semantic_slot_refs = 2`
- `jl_slot_refs = 2`
- `semantic_slot_refs_match = true`
- `manual_distinct_slots = 1`
- `jl_distinct_slots = 1`

Meaning:
- global refs line up
- semantic slot-use counts line up
- distinct slot counts line up

The current code-level preflight is also explicit:

```julia
experimental_generator_filter_slice_status(
    "(i + x for i in 1:x if i < x)";
    outer_bindings=[:x],
)
```

- on Julia `1.11`: `(supported = true, contract_met = false)`
- on Julia `1.12+` with JuliaLowering loaded: this is expected to become the one-call preflight for the first slice

This is the narrowest currently proven boundary that looks adapter-worthy.

## Explicitly in scope
1. Generator/filter proof cases of the same general shape:
   - one generator binder
   - outer references allowed
   - optional filter condition
2. Proof-only adapter or comparison code that maps/normalizes JuliaLowering output enough to compare against existing manual expectations.
3. Keeping the default/manual scoping backend unchanged.
4. Julia `1.11` support preserved for the package’s default path.
5. JuliaLowering experimentation allowed behind explicit helper seams under Julia `1.12+`.

## Explicitly out of scope for slice 1
1. Nested comprehensions
2. Multi-binder comprehensions
3. Full backend replacement for `@resumable`
4. Broad Expr regeneration from arbitrary JuliaLowering output
5. Any change that makes JuliaLowering a required dependency for normal package use on Julia `1.11`

## Normalization rules already justified by proof work
### 1. Strip JuliaLowering synthetic wrapper globals
For proof comparisons, ignore synthetic anonymous-wrapper globals like:
- `#->##0`
- `#->##1`
- etc.

Reason: these are lowering artifacts, not the semantic operator/outer-binding/globalref surface of interest for the first slice.

### 2. Treat generator binder definition separately from semantic slot uses
On the manual side, the scoped Expr includes the generator binder definition on the assignment LHS:

```julia
(i_0 + x for i_0 = 1:x if i_0 < x)
```

The manual proof path therefore sees three local-slot-like occurrences of `i_0`:
- body use
- filter use
- binder-definition LHS

For the first slice, only the first two count as **semantic slot uses**.

Reason: JuliaLowering’s normalized proof summary is effectively closer to semantic use counts than raw binder-definition bookkeeping counts.

## Proposed acceptance contract for slice 1
A first JuliaLowering-backed adapter/proof slice is good enough if it can demonstrate all of the following on at least the representative generator/filter case:

1. **Global-ref sequence agreement**
   - operators and outer refs line up after normalization
2. **Semantic slot-use agreement**
   - excluding binder-definition bookkeeping on the manual side
3. **Distinct slot agreement**
   - same number of distinct generator-bound locals recognized
4. **No default-path regression**
   - `Pkg.test(test_args=["main"])` still passes on Julia `1.11`
5. **JuliaLowering remains experimental**
   - no forced dependency on the default/manual path

## Likely smallest implementation options from here
### Option A — Comparison-first helper only
Add a tiny helper dedicated to generator/filter proof cases that returns a normalized comparison object and leaves backend wiring untouched.

Use if the goal is one more confidence-building, reviewable step.

### Option B — Experimental adapter stub for generator/filter seam
Implement a very narrow experimental adapter behind `JuliaLoweringScopingBackend` that only handles the proven generator/filter shape and otherwise errors clearly.

Use only if the maintainer-facing value of a tiny executable adapter now outweighs the risk of moving too fast.

## Recommended next move
Prefer **Option A if more proof is needed**, or **Option B if ready to turn the proof boundary into code**.

If choosing Option B, keep the contract brutally narrow:
- generator/filter only
- one binder only
- no nested comprehensions
- explicit fallback/error for everything else

## Why not nested comprehensions yet
The current proof work shows nested comprehensions still carry substantially more JuliaLowering slot activity than the manual proof summary, even after synthetic wrapper normalization.

That means nested comprehensions are still a poor candidate for the first adapter slice and would blur the boundary that is finally becoming crisp.
