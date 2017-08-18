using ResumableFunctions
using Base.Test

@resumable function test_for()
  for i in 1:10
    println(i)
  end
end

test_for()
