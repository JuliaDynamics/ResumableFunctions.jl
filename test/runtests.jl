using ResumableFunctions
using Base.Test

@resumable function test_for(a::Int=0) :: Int
  b = a + 1
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
@test String(copy(io)) == "SpecialException()\nhello\nAlways\n"

io = IOBuffer()
try_me = test_try(io)
try_me()
try_me()
@test try_me("hello") == 2
@test String(copy(io)) == "hello\nAlways\n"

io = IOBuffer()
try_me = test_try(io)
try_me()
try_me()
try_me(SpecialException())
@test try_me("hello") == 2
@test_throws ErrorException try_me()
@test String(copy(io)) == "SpecialException()\nhello\nAlways\n"
end #test_try
