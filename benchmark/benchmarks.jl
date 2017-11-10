using BenchmarkTools, Compat
using ResumableFunctions

const n = 93

@noinline function fibonnaci_direct(a::Int, b::Int)
  b, a+b
end

function test_direct()
  a = zero(Int)
  b = a + one(a)
  for i in 1:n 
    a, b = fibonnaci_direct(a, b)
  end
end

println("Direct: ")
@btime test_direct()

@resumable function fibonnaci_resumable()
  a = zero(Int)
  b = a + one(a)
  while true
    @yield a
    a, b = b, a + b
  end
end

function test_resumable()
  fib_resumable = fibonnaci_resumable()
  for i in 1:n 
    fib_resumable() 
  end
end

println("ResumableFunctions: ")
@btime test_resumable()

function my_produce(v)
  ct = current_task()
  consumer = ct.consumers
  ct.consumers = nothing
  Base.schedule_and_wait(consumer, v)
  return consumer.result
end

function my_consume(producer::Task, values...)
  istaskdone(producer) && return producer.value
  ct = current_task()
  ct.result = length(values)==1 ? values[1] : values
  producer.consumers = ct
  Base.schedule_and_wait(producer)
end

function fibonnaci_produce()
  a = zero(Int)
  b = a + one(a)
  while true
    my_produce(a)
    a, b = b, a + b
  end
end

function test_produce()
  fib_produce = @task fibonnaci_produce()
  for i in 1:n 
    my_consume(fib_produce) 
  end
end

println("Produce/consume: ")
@btime test_produce()

function fibonnaci_channel(ch::Channel)
  a = zero(Int)
  b = a + one(a)
  while true
    put!(ch, a)
    a, b = b, a + b
  end
end

function test_channel(csize::Int)
  fib_channel = Channel(fibonnaci_channel; ctype=Int, csize=csize)
  for i in 1:n 
    take!(fib_channel) 
  end
end

println("Channels csize=0: ")
@btime test_channel(0)

println("Channels csize=20: ")
@btime test_channel(20)

println("Channels csize=100: ")
@btime test_channel(100)

function fibonnaci_closure()
  a = zero(Int)
  b = a + one(Int)
  function()
    tmp = a
    a, b = b, a + b
    tmp
  end
end

function test_closure()
  fib_closure = fibonnaci_closure()
  for i in 1:n 
    fib_closure() 
  end
end

println("Closure: ")
@btime test_closure()

function fibonnaci_closure_opt()
  a = Ref(zero(Int))
  b = Ref(a[] + one(Int))
  function()
    tmp = a[]
    a[], b[] = b[], a[] + b[]
    tmp
  end
end

function test_closure_opt()
  fib_closure = fibonnaci_closure_opt()
  for i in 1:n 
    fib_closure() 
  end
end

println("Closure optimised: ")
@btime test_closure_opt()

function fibonnaci_closure_stm()
  a = Ref(zero(Int))
  b = Ref(a[] + one(Int))
  _state = Ref(zero(UInt8))
  (_arg::Any=nothing)->begin
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

function test_closure_stm()
  fib_closure = fibonnaci_closure_stm()
  for i in 1:n 
    fib_closure() 
  end
end

println("Closure statemachine: ")
@btime test_closure_stm()