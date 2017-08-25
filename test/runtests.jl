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

for a in test_for(4)
  println(a)
end

@resumable function test_try()
  try
    a = 1
    @yield a
    a = 2
    c = @yield a
    println(c)
  catch except
    println(except)
    d = @yield
    println(d)
  finally
    println("Always")
  end
  a
end

struct SpecialException <: Exception end

try_me = test_try()
try_me()
try_me(SpecialException())
println(try_me("hello"))

try_me = test_try()
try_me()
try_me()
println(try_me("hello"))

try_me = test_try()
try_me()
try_me()
try_me(SpecialException())
println(try_me("hello"))
try
  try_me()
catch exc
  println(exc)
end