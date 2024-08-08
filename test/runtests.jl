using ResumableFunctions
using Test
using SafeTestsets

function doset(descr)
    if length(ARGS) == 0
        return true
    end
    for a in ARGS
        if occursin(lowercase(a), lowercase(descr))
            return true
        end
    end
    return false
end

macro doset(descr)
    quote
        @info "====================================="
        @info $descr
        if doset($descr)
            @safetestset $descr begin
                include("test_"*$descr*".jl")
            end
        end
    end
end

println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")

@doset "main"
@doset "yieldfrom"
@doset "typeparams"
@doset "repeated_variable"
@doset "inference_recursive_calls"
@doset "selfreferencing_functional"
@doset "coverage_preservation"
@doset "performance"
VERSION >= v"1.8" && @doset "doctests"
VERSION >= v"1.8" && @doset "aqua"
get(ENV,"JET_TEST","")=="true" && @doset "jet"
