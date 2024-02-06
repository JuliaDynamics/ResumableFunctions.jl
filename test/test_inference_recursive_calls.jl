using Test
using ResumableFunctions

##

@resumable function rec1(a::Int)::Int
    @yield a
    if a > 0
        for i in rec1(a-1)
            @yield i
        end
    end
end
@test collect(rec1(4)) isa Vector{Int}
@test collect(rec1(4)) == 4:-1:0

##

@resumable function rec2(a::Int)::Any
    @yield a
    if a > 0
        for i in rec2(a-1)
            @yield i
        end
    end
end
@test collect(rec2(4)) isa Vector{Any}
@test collect(rec2(4)) == 4:-1:0

##

@resumable function rec3(a)
    @yield a
    if a > 0
        for i in rec3(a-1)
            @yield i
        end
    end
end
@test collect(rec3(4)) isa Vector{Any}
@test collect(rec3(4)) == 4:-1:0

##

# From issue #80

@resumable function rf!(a::Vector{Int}, i::Integer, n::Integer)::Vector{Int}
    if i > n
        @yield a
        return
    end
    a[i] = 0
    for _ in rf!(a, i+1, n)
        @yield a
    end
    for k = i+1:n
        a[i] = k
        a[k] = i
        for _ in rf!(a, i+1, k-1)
            for _ in rf!(a, k+1, n)
            @yield a
            end
        end
    end
end

const n = 3
const a = zeros(Int, n)
collect(rf!(a, 1, n)) == [[3, 0, 1],
                          [3, 0, 1],
                          [3, 0, 1],
                          [3, 0, 1]]
