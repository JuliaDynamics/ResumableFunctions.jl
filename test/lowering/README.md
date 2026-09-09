Tests for the JuliaLowering-backed scope resolution.

JuliaLowering.jl is not registered and needs Julia 1.12, so these run from their own environment
rather than from `test/Project.toml`, which has to keep resolving on the versions the package
supports. Run them with:

    julia --project=test/lowering test/lowering/runtests.jl

The runner instantiates its own environment, which fetches the two pinned revisions.
