# ResumableFunctions #99 patch relay bundle

Date: 2026-03-23
Repo: `JuliaDynamics/ResumableFunctions.jl`
Branch source: `bounty-99-julialowering-scout`
Bundle range: `7a4614b^..b1d8ba9`

## What this bundle contains
A linear patch series covering the validated generator/filter seam success-path packaging work:

1. `0001` — fix the readiness false-negative by using unquoted Expr source
2. `0002` — record the validated seam success path
3. `0003` — clarify seam smoke status wording
4. `0004` — note the explicit smoke `STATUS=` outputs
5. `0005` — sync the adapter-target note with exact smoke wording
6. `0006` — add the maintainer handoff snapshot

## Suggested apply flow
From a checkout of the target repo:

```bash
git am reports/patches/resumablefunctions-99-2026-03-23/*.patch
```

If reviewing before apply:

```bash
git apply --stat reports/patches/resumablefunctions-99-2026-03-23/*.patch
```

## Companion docs
- `reports/resumablefunctions-99-generator-adapter-target-2026-03-21.md`
- `reports/resumablefunctions-99-maintainer-handoff-2026-03-23.md`
- `examples/experimental_julialowering_seam_readiness.jl`
