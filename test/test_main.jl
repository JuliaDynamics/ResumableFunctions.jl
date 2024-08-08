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
@test endswith(String(take!(copy(io))), "SpecialException()\nAlways\n")

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
@test endswith(String(take!(copy(io))), "SpecialException()\nAlways\n")
end

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
      local val
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

if VERSION >= v"1.8"

@resumable function test_let2()
  for u in [[(1,2),(3,4)], [(5,6),(7,8)]]
    for i in 1:2
      local val
      let i=i, j=i
        val = [(a[i],a[j]) for a in u]
      end
      @yield val
    end
  end
end

@testset "test_let2" begin
@test collect(test_let2()) == [[(1, 1), (3, 3)], [(2, 2), (4, 4)], [(5, 5), (7, 7)], [(6, 6), (8, 8)]]
end

@resumable function test_let_noassignment()
  for u in [[(1,2),(3,4)], [(5,6),(7,8)]]
    for i in 1:2
      local val
      let i
        val = [a[1] for a in u]
      end
      @yield val
    end
  end
end

@testset "test_let_noassignment" begin
collect(test_let_noassignment()) == [[1, 3], [1, 3], [5, 7], [5, 7]]
end

@resumable function test_let_multipleargs()
  for u in [[(1,2),(3,4)], [(5,6),(7,8)]]
    for i in 1:2
      local val
      let i=i, j
        val = [a[i] for a in u]
      end
      @yield val
    end
  end
end

@testset "test_let_multipleargs" begin
@test collect(test_let_multipleargs()) == [[1, 3], [2, 4], [5, 7], [6, 8]]
end

end # VERSION >= v"1.8"

@resumable function test_nosave()
  for i in 65:74
    @nosave tmp = Char(i)
    @yield tmp
  end
end

@testset "test_nosave" begin
@test collect(test_nosave()) == ['A', 'B', 'C', 'D', 'E',  'F', 'G', 'H', 'I', 'J']
end

@resumable function test_return_value()
  return 1
end

@testset "test_return_value" begin
  @test collect(test_return_value()) == []
end

@resumable function test_continue()
  for i in 1:10
    if i === 2
      continue
    end
    @yield i
  end
end

@resumable function test_continue_double()
  for i in 1:3
    if i === 2
      continue
    end
    for j in 1:3
      if j === 2
        continue
      end
      @yield j
    end
  end
end

@testset "test_continue" begin
  @test collect(test_continue()) == [1, 3, 4, 5, 6, 7, 8, 9, 10]
  @test collect(test_continue_double()) == [1, 3, 1, 3]
end

"""docstring"""
@resumable function fwithdoc()
    @yield 1
end

"""docstring"""
function gwithdoc()
    return 1
end

@testset "test_docstring" begin
@test (@doc fwithdoc) == (@doc gwithdoc)
end

@resumable function test_unstable(a::Int)
  for i in 1:a
    a = "number $i"
    @yield a
  end
end

@testset "test_unstable" begin
  @test collect(test_unstable(3)) == ["number 1", "number 2", "number 3"]
end

@testset "test_scope" begin
@resumable function test_scope_throws()
  for u in [[(1,2),(3,4)], [(5,6),(7,8)]]
    for i in 1:2
      let i=i, j
        val = [a[i] for a in u]
      end
      @yield val
    end
  end
end
@test_throws UndefVarError collect(test_scope_throws())

# test length

@testset "test_length" begin
  @resumable length=n^2*m^2 function test_length(n, m)
    for i in 1:n^2
      for j in 1:m^2
        @yield i + j
      end
    end
  end

  @test length(test_length(10, 20)) === 10^2 * 20^2
  @test length(collect(test_length(10, 20))) === 10^2 * 20^2
  @test Base.IteratorSize(typeof(test_length(1, 1))) == Base.HasLength()
end
