using Test
using Semicoroutines

@resumable function test_yieldfrom_inner(n)
  for i in 1:n
    @yield i^2
  end
  42, n
end

@resumable function test_yieldfrom(n)
  @yieldfrom [42, 314]   
  m, n = @yieldfrom test_yieldfrom_inner(n)
  @test m == 42
  @yield n
  @yieldfrom test_yieldfrom_inner(n+1)
end

@testset "test_yieldfrom" begin
@test collect(test_yieldfrom(4)) == [42, 314, 1, 4, 9, 16, 4, 1, 4, 9, 16, 25]
end

@resumable function test_echo()
  x = 0
  while true
    x = @yield x
  end
  return "Done"
end

@resumable function test_forward()
  ret = @yieldfrom test_echo()
  @test ret == "Done"
  @yieldfrom test_echo()
end

@testset "test_yieldfrom_twoway" begin
  forward = test_forward()
  @test forward() == 0
  for i in 1:5
    @test forward(i) == i
  end
end
