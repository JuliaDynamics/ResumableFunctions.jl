using BenchmarkTools
using ResumableFunctions

const n = 93

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