using Test
using Semicoroutines

@testset "test_continue" begin
  @test collect(test_continue()) == [1, 3, 4, 5, 6, 7, 8, 9, 10]
  @test collect(test_continue_double()) == [1, 3, 1, 3]
end

@resumable function test_yield_from_inner(n)
  for i in 1:n
    @yield i^2
  end
  42, n
end

@resumable function test_yield_from(n)
  @yield_from [42, 314]   
  m, n = @yield_from test_yield_from_inner(n)
  @test m == 42
  @yield n
  @yield_from test_yield_from_inner(n+1)
end

@testset "test_yield_from" begin
@test collect(test_yield_from(4)) == [42, 314, 1, 4, 9, 16, 4, 1, 4, 9, 16, 25]
end

@resumable function test_echo()
  x = 0
  while true
    x = @yield x
  end
  return "Done"
end

@resumable function test_forward()
  ret = @yield_from test_echo()
  @test ret == "Done"
  @yield_from test_echo()
end

@testset "test_yield_from_twoway" begin
  forward = test_forward()
  @test forward() == 0
  for i in 1:5
    @test forward(i) == i
  end
end
