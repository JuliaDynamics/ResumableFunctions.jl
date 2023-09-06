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
