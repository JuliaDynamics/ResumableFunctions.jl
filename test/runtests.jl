using ResumableFunctions
using Base.Test

@resumable function test_for(a::Int=0; b::Int=a+1) :: Int
  for i in 1:9
    @yield a
    a, b = b, a+b
  end
  a
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
    d = @yield
    println(io,d)
  finally
    println(io,"Always")
  end
  a
end

struct SpecialException <: Exception end
@testset "test_try" begin
io = IOBuffer()
try_me = test_try(io)
try_me()
try_me(SpecialException())
@test try_me("hello") == 1
@test String(take!(copy(io))) == "SpecialException()\nhello\nAlways\n"

io = IOBuffer()
try_me = test_try(io)
try_me()
try_me()
@test try_me("hello") == 2
@test String(take!(copy(io))) == "hello\nAlways\n"

io = IOBuffer()
try_me = test_try(io)
try_me()
try_me()
try_me(SpecialException())
@test try_me("hello") == 2
@test_throws ErrorException try_me()
@test String(take!(copy(io))) == "SpecialException()\nhello\nAlways\n"
end #test_try

@resumable function (test_where1(a::N) :: N) where {N<:Number}
  b = a + one(N)
  for i in 1:9
    @yield a
    a, b = b, a+b
  end
  a
end

@resumable function (test_where2(a::N) :: N) where N
  b = a + one(N)
  for i in 1:9
    @yield a
    a, b = b, a+b
  end
  a
end

@testset "test_where" begin
@test collect(test_where1(4.0)) == [4.0, 5.0, 9.0, 14.0, 23.0, 37.0, 60.0, 97.0, 157.0, 254.0]
@test collect(test_where2(4)) == [4, 5, 9, 14, 23, 37, 60, 97, 157, 254]
end