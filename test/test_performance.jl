using ResumableFunctions
using Test

@resumable function fibonacci_resumable(n::Int)
  a, b = zero(Int), one(Int)
  for _ in 1:n
    @yield a
    a, b = b, a + b
  end
end

@noinline function test_resumable(n::Int)
  a = 0
  for v in fibonacci_resumable(n)
    a = v
  end
  a
end

@test (@allocated test_resumable(80))==0


@resumable function cumsum(iter)
  acc = zero(eltype(iter))
  for i in iter
    acc += i
    @yield acc
  end
end

# versions that support generating inferred code
if VERSION >= v"1.10.0-DEV.873"
  cs = cumsum(1:1000)
  @allocated cs() # shake out the compilation overhead
  @test (@allocated cs())==0
end