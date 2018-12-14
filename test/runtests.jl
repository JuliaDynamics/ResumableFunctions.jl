using ResumableFunctions
using Test

@resumable function test_for(a::Int=0; b::Int=a+1) :: Int
  for i in 1:10
    @yield a
    a, b = b, a+b
  end
end

@testset "test_for" begin
@test collect(test_for(4)) == [4, 5, 9, 14, 23, 37, 60, 97, 157, 254]
end

@resumable function test_try(io)
  try
    a = 1
    @yield a
    a = 2
    c = @yield a
    println(io,c)
  catch except
    println(io,except)
  finally
    println(io,"Always")
  end
end

struct SpecialException <: Exception end
@testset "test_try" begin
io = IOBuffer()
try_me = test_try(io)
try_me()
try_me(SpecialException())
@test String(take!(copy(io))) == "SpecialException()\nAlways\n"

io = IOBuffer()
try_me = test_try(io)
try_me()
try_me()
try_me("Hello")
@test String(take!(copy(io))) == "Hello\nAlways\n"

io = IOBuffer()
try_me = test_try(io)
try_me()
try_me()
try_me(SpecialException())
@test_throws ErrorException try_me()
@test String(take!(copy(io))) == "SpecialException()\nAlways\n"
end #test_try

@resumable function (test_where1(a::N) :: N) where {N<:Number}
  b = a + one(N)
  for i in 1:10
    @yield a
    a, b = b, a+b
  end
end

@resumable function (test_where2(a::N=4; b::N=a + one(N)) :: N) where N
  for i in 1:10
    @yield a
    a, b = b, a+b
  end
end

@testset "test_where" begin
@test collect(test_where1(4.0)) == [4.0, 5.0, 9.0, 14.0, 23.0, 37.0, 60.0, 97.0, 157.0, 254.0]
@test collect(test_where2(4)) == [4, 5, 9, 14, 23, 37, 60, 97, 157, 254]
end

@resumable function test_varargs(a...)
  for (i, e) in enumerate(a)
    @yield e
  end
end

@testset "test_varargs" begin
@test collect(test_varargs(1, 2, 3)) == [1, 2, 3]
end

@resumable function test_let()
  for u in [[(1,2),(3,4)], [(5,6),(7,8)]]
    for i in 1:2
      let i=i
        val = [a[i] for a in u]
      end
      @yield val
    end
  end
end

@testset "test_let" begin
@test collect(test_let()) == [[1,3],[2,4],[5,7],[6,8]]
end

@resumable function test_return_value()
  return 1
end

@testset "test_return_value" begin
  @test collect(test_return_value()) == []
end