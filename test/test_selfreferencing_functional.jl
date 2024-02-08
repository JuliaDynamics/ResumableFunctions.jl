using Test
using ResumableFunctions

struct A
    a::Int
end;
@resumable function (fa::A)(b::Int)
    @yield b+fa.a
end

@test collect(A(1)(2)) == [3]
@test_broken collect(A(1)(2)) isa Vector{Int}
