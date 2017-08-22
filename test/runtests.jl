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
  catch
    println("Exception")
  end
end