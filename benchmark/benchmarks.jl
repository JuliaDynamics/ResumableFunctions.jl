using BenchmarkTools, ResumableFunctions
using ResumableFunctions

const n = 93

function direct_fib(n)
  a = zero(Int)
  b = a + one(a)
  for i in 1:n-1
    a, b = b, a+b
  end#for
  a
end#function

@resumable function fibonnaci_resumable(n)
  a = zero(Int)
  b = a + one(a)
  for i in 1:n
    @yield a
    a, b = b, a + b
  end
end

function test_resumable(n)
  a = 0
  for i in fibonnaci_resumable(n)
    a = i
  end#for
  a
end

function fibonnaci_channel(n, ch::Channel)
  a = zero(Int)
  b = a + one(a)
  for i in 1:n
    put!(ch, a)
    a, b = b, a + b
  end
end

function test_channel(n, csize::Int)
  fib_channel = Channel(c -> fibonnaci_channel(n, c); ctype=Int, csize=csize)
  a = 0
  for i in fib_channel
    a = i
  end#for
  a
end

function fibonnaci_closure()
  a = zero(Int)
  b = a + one(Int)
  function()
    tmp = a
    a, b = b, a + b
    tmp
  end
end

function test_closure(n)
  fib_closure = fibonnaci_closure()
  a = 0
  for i in 1:n
    a = fib_closure()
  end
  a
end

function fibonnaci_closure_opt()
  a = Ref(zero(Int))
  b = Ref(a[] + one(Int))
  @noinline function()
    tmp = a[]
    a[], b[] = b[], a[] + b[]
    tmp
  end
end

function test_closure_opt(n)
  fib_closure = fibonnaci_closure_opt()
  a = 0
  for i in 1:n 
    a = fib_closure() 
  end
  a
end

function fibonnaci_closure_stm()
  a = Ref(zero(Int))
  b = Ref(a[] + one(Int))
  _state = Ref(zero(UInt8))
  function(_arg::Any=nothing)
    _state[] == 0x00 && @goto _STATE_0
    _state[] == 0x01 && @goto _STATE_1
    error("@resumable function has stopped!")
    @label _STATE_0
    _state[] = 0xff
    _arg isa Exception && throw(_arg)
    while true
      _state[] = 0x01
      return a[]
      @label _STATE_1
      _state[] = 0xff
      _arg isa Exception && throw(_arg)
      a[], b[] = b[], a[] + b[]
    end
  end
end

function test_closure_stm(n)
  fib_closure = fibonnaci_closure_stm()
  a = 0
  for i in 1:n 
    a = fib_closure() 
  end
  a
end

struct FibN
  n::Int
end

function Base.iterate(f::FibN, state::NTuple{3,Int}=(0, 1, 1))
  @inbounds state[3] >= f.n && return nothing
  a, b, iters = state
  @inbounds b, (b, a + b, iters + 1)
end

function test_iteration_protocol(n)
  fib = FibN(n)
  a = 0
  for i in fib
    a = i
  end
  a
end

isinteractive() || begin
  println("Direct: ")
  @btime direct_fib($n)
  @assert direct_fib(n) == 7540113804746346429

  println("ResumableFunctions: ")
  @btime test_resumable($n)
  @assert direct_fib(n) == 7540113804746346429

  println("Channels csize=0: ")
  @btime test_channel($n, $0)
  @assert test_channel(n, 0) == 7540113804746346429

  println("Channels csize=1: ")
  @btime test_channel($n, $1)
  @assert test_channel(n, 1) == 7540113804746346429

  println("Channels csize=20: ")
  @btime test_channel($n, $20)
  @assert test_channel(n, 20) == 7540113804746346429

  println("Channels csize=100: ")
  @btime test_channel($n, $100)
  @assert test_channel(n, 100) == 7540113804746346429

  println("Closure: ")
  @btime test_closure($n)
  @assert test_closure(n) == 7540113804746346429

  println("Closure optimised: ")
  @btime test_closure_opt($n)
  @assert test_closure_opt(n) == 7540113804746346429

  println("Closure statemachine: ")
  @btime test_closure_stm($n)
  @assert test_closure_stm(n) == 7540113804746346429

  println("Iteration protocol: ")
  @btime test_iteration_protocol($n)
  @assert test_iteration_protocol(n) == 7540113804746346429
end
