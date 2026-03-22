using ResumableFunctions

const EXPR_SRC = "(i + x for i in 1:x if i < x)"

function main()
    println("EXPR=$EXPR_SRC")
    println("JULIA_VERSION=$(VERSION)")

    expr = Meta.parse(EXPR_SRC)
    scope = ResumableFunctions.init_scope_tracker([:x], Symbol[], :example_backend, Symbol[], Main)
    readiness = ResumableFunctions.experimental_generator_filter_slice_readiness(expr, scope)

    println("SUPPORTED=$(readiness.supported)")
    println("OUTER_BINDINGS=$(join(string.(readiness.outer_bindings), ","))")
    println("CONTRACT_MET=$(readiness.contract_met)")

    if VERSION < v"1.12.0"
        println("NOTE=JuliaLowering proof path requires Julia 1.12+")
        return
    end

    if Base.find_package("JuliaLowering") === nothing
        println("NOTE=JuliaLowering is not installed in this environment")
        return
    end

    @eval using JuliaLowering

    readiness = ResumableFunctions.experimental_generator_filter_slice_readiness(expr, scope)
    println("POSTLOAD_SUPPORTED=$(readiness.supported)")
    println("POSTLOAD_OUTER_BINDINGS=$(join(string.(readiness.outer_bindings), ","))")
    println("POSTLOAD_CONTRACT_MET=$(readiness.contract_met)")
end

main()
