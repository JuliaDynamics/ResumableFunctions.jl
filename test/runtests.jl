using ResumableFunctions
using Base.Test

@resumable function test_for(a::Int=0) :: Int
  b = a + 1
  for i in 1:10
    @yield a
    a, b = b, a+b
  end
end

for a in test_for(1)
  println(a)
end

@resumable function test_try()
  try
    a = 1
    @yield a
    a = 2
    c = @yield a
  catch exc
    println(exc)
  end
end