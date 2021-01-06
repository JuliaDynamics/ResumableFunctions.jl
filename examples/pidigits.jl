#= The Computer Language Benchmarks Game
   https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

   contributed by Ben Lauwens

   derived from the Chapel version by Tom Hildebrandt, Brad Chamberlain, and Lydia Duncan
   and inspired by the Julia version of Luiz M. Faria
=#

using BenchmarkTools
using ResumableFunctions

using Base.GMP.MPZ: add_ui!, mul_ui!, add!, tdiv_q!
const mpz_t = Ref{BigInt}
addmul_ui!(x::BigInt,a::BigInt,b::Int64) = ccall((:__gmpz_addmul_ui,"libgmp"), Cvoid, (mpz_t,mpz_t,Culong), x, a, b)
submul_ui!(x::BigInt,a::BigInt,b::UInt64) = ccall((:__gmpz_submul_ui,"libgmp"), Cvoid, (mpz_t,mpz_t,Culong), x, a, b)
get_ui(x::BigInt) = ccall((:__gmpz_get_ui,"libgmp"), Culong, (mpz_t,), x)

@resumable function pidigits(n::Int64)
    i = 1
    k = 1
    d = 0
    numer = BigInt(1)
    denom = BigInt(1)
    accum = BigInt(0)
    tmp1 = BigInt(0)
    tmp2 = BigInt(0)
    while i <= n
        k2 = 2k + 1
        addmul_ui!(accum, numer, 2)
        mul_ui!(accum, k2)
        mul_ui!(denom, k2)
        mul_ui!(numer, k)
        k += 1
        if numer <= accum
            mul_ui!(tmp1, numer, 3)
            add!(tmp1, accum)
            tdiv_q!(tmp2, tmp1, denom)
            d = get_ui(tmp2)
            mul_ui!(tmp1, numer, 4)
            add!(tmp1, accum)
            tdiv_q!(tmp2, tmp1, denom)
            if d == get_ui(tmp2)
                @yield (d, i)
                submul_ui!(accum, denom, d)
                mul_ui!(accum, 10)
                mul_ui!(numer, 10)
                i += 1
            end
        end
    end
end

function main(n = parse(Int64, ARGS[1]))
    i = 0
    v = 0
    for (d, i) in pidigits(n)
        print(d)
        if i % 10 === 0
            println("\t:", i)
        end
        v = d
    end
    if i % 10 !== 0
        println(" "^(10 - (i % 10)), "\t:", n)
    end
    v
end

main(100)
#@btime main(10000)