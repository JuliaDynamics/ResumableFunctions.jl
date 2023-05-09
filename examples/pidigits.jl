#= The Computer Language Benchmarks Game
   https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

   contributed by Ben Lauwens

   derived from the Chapel version by Tom Hildebrandt, Brad Chamberlain, and Lydia Duncan
   and inspired by the Julia version of Luiz M. Faria
=#

using ResumableFunctions

using Base.GMP.MPZ: add_ui!, mul_ui!, add!, tdiv_q!
const mpz_t = Ref{BigInt}
addmul_ui!(x::BigInt,a::BigInt,b::UInt64) = ccall((:__gmpz_addmul_ui,"libgmp"), Cvoid, (mpz_t,mpz_t,Culong), x, a, b)
submul_ui!(x::BigInt,a::BigInt,b::UInt64) = ccall((:__gmpz_submul_ui,"libgmp"), Cvoid, (mpz_t,mpz_t,Culong), x, a, b)
get_ui(x::BigInt) = ccall((:__gmpz_get_ui,"libgmp"), Culong, (mpz_t,), x)

@resumable function pidigits()
    k = one(UInt64)
    d = zero(UInt64)
    numer = BigInt(1)
    denom = BigInt(1)
    accum = BigInt(0)
    tmp1 = BigInt(0)
    tmp2 = BigInt(0)
    tmp3 = BigInt(0)
    while true
        k2 = 2k + one(UInt64)
        addmul_ui!(accum, numer, UInt64(2))
        mul_ui!(accum, k2)
        mul_ui!(denom, k2)
        mul_ui!(numer, k)
        k += one(UInt64)
        if numer <= accum
            mul_ui!(tmp1, numer, UInt64(3))
            add!(tmp1, accum)
            tdiv_q!(tmp2, tmp1, denom)
            mul_ui!(tmp1, numer, UInt64(4))
            add!(tmp1, accum)
            tdiv_q!(tmp3, tmp1, denom)
            if tmp2 == tmp3
                d = get_ui(tmp2)
                @yield d
                submul_ui!(accum, denom, d)
                mul_ui!(accum, UInt64(10))
                mul_ui!(numer, UInt64(10))
            end
        end
    end
end

function main(n = parse(Int64, ARGS[1]))
    i = 0
    pid = pidigits()
    for i in 1:n
        d = pid()
        print(d)
        if i % 10 === 0
            println("\t:", i)
        end
    end
    if i % 10 !== 0
        println(" "^(10 - (i % 10)), "\t:", n)
    end
end


main(100)