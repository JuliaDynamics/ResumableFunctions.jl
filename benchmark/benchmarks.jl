using BenchmarkTools, ResumableFunctions
using ResumableFunctions

const n = 93

const N = BigInt

function direct(a::N, b::N)
  b, a+b
end

function test_direct(n::Int)
  a, b = zero(N), one(N)
  for _ in 1:n-1
    a, b = direct(a, b)
  end
  a
end

@resumable function fibonacci_resumable(n::Int)
  a, b = zero(N), one(N)
  for _ in 1:n
    @yield a
    a, b = b, a + b
  end
end

@noinline function test_resumable(n::Int)
  a = 0
  for v in fibonacci_resumable(n)
    a = v
  end
  a
end

function fibonacci_channel(n::Int, ch::Channel)
  a, b = zero(N), one(N)
  for _ in 1:n
    put!(ch, a)
    a, b = b, a + b
  end
end

@noinline function test_channel(n::Int, csize::Int)
  fib_channel = Channel(c -> fibonacci_channel(n, c); ctype=N, csize=csize)
  a = 0
  for v in fib_channel
    a = v
  end
  a
end

struct Generator
  callee :: Task
  function Generator(f::Function, args...; kwargs...)
      ct = current_task()
      new(@task begin task_local_storage(:caller, ct); f(args...; kwargs...); yield(ct) end)
  end
end

function Base.iterate(gen::Generator, state=nothing)
  ret = yieldto(gen.callee)
  if ret === nothing return nothing end
  ret, nothing
end

function consume(gen::Generator, val=nothing)
  yieldto(gen.callee, val)
end


function produce(val=nothing)
  t = task_local_storage(:caller)
  yieldto(t, val)
end

function fibonacci_task(n::Int)
  a,b = zero(N), one(N)
  for _ in 1:n
      produce(a)
      a, b = b, a+b
  end
end

@noinline function test_task(n::Int)
  a = 0
  for v in Generator(fibonacci_task, n)
    a = v
  end
  a
end

function fibonacci_closure()
  a, b = zero(N), one(N)
  function()
    tmp = a
    a, b = b, a + b
    tmp
  end
end

@noinline function test_closure(n::Int)
  fib_closure = fibonacci_closure()
  a = 0
  for _ in 1:n
    a = fib_closure()
  end
  a
end

function fibonacci_closure_opt()
  a = Ref(zero(N))
  b = Ref(one(N))
  function()
    tmp = a[]
    a[], b[] = b[], a[] + b[]
    tmp
  end
end

@noinline function test_closure_opt(n::Int)
  fib_closure = fibonacci_closure_opt()
  a = 0
  for _ in 1:n 
    a = fib_closure() 
  end
  a
end

function fibonacci_closure_stm(n::Int)
  _state = Ref(0x00)
  a = Ref{N}()
  b = Ref{N}()
  _iterstate_1 = Ref{Int}()
  _iterator_1 = Ref{UnitRange{Int}}()

  function(_arg::Any=nothing)
    _state[] === 0x00 && @goto _STATE_0
    _state[] === 0x01 && @goto _STATE_1
    error("@resumable function has stopped!")
    @label _STATE_0
    _state[] = 0xff
    _arg isa Exception && throw(_arg)
    a[], b[] = zero(Int), one(Int)
    _iterator_1[] = 1:n
    _iteratornext_1 = iterate(_iterator_1[])
    while _iteratornext_1 !== nothing
      (_, _iterstate_1[]) = _iteratornext_1
      _state[] = 0x01
      return a[]
      @label _STATE_1
      _state[] = 0xff
      _arg isa Exception && throw(_arg)
      (a[], b[]) = (b[], a[] + b[])
      _iteratornext_1 = iterate(_iterator_1[], _iterstate_1[])
    end
  end
end

const FibClosure = typeof(fibonacci_closure_stm(n))

function Base.iterate(f::FibClosure, state=nothing)
  a = f()
  f._state[] === 0xff && return nothing
  a, nothing
end

@noinline function test_closure_stm(n::Int)
  fib_closure = fibonacci_closure_stm(n)
  a = 0
  for v in fibonacci_closure_stm(n)
    a = v
  end
  a
end

struct FibN
  n::Int
end

function Base.iterate(f::FibN, state::Tuple{N, N, Int}=(zero(N), one(N), 1))
  a, b, iters = state
  iters > f.n && return nothing
  a, (b, a + b, iters + 1)
end

@noinline function test_iteration_protocol(n::Int)
  a = 0
  for v in FibN(n)
    a = v
  end
  a
end

isinteractive() || begin
  println("Direct: ")
  @btime test_direct($n)
  @assert test_direct(n) == 7540113804746346429

  println("ResumableFunctions: ")
  @btime test_resumable($n)
  @assert test_resumable(n) == 7540113804746346429

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

  println("Task scheduling")
  @btime test_task($n)
  @assert test_task(n) == 7540113804746346429

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
