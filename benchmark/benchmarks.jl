using BenchmarkTools
using ResumableFunctions

const n = 100

@resumable function fibonnaci_resumable(a::Int)
  b = a + one(a)
  while true
    @yield a
    a, b = b, a + b
  end
end

fib_resumable = fibonnaci_resumable(0)
println("ResumableFunctions: ")
@btime for i in 1:n fib_resumable() end

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

function fibonnaci_produce(a::Int)
  b = a + one(a)
  while true
    my_produce(a)
    a, b = b, a + b
  end
end

fib_produce = @task fibonnaci_produce(0)
println("Produce/consume: ")
@btime for i in 1:n my_consume(fib_produce) end

function fibonnaci_channel(ch::Channel, a)
  b = a + one(a)
  while true
    put!(ch, a)
    a, b = b, a + b
  end
end

fib_channel_0 = Channel(chan->fibonnaci_channel(chan, 0); ctype=Int, csize=0)
println("Channels csize=0: ")
@btime for i in 1:n take!(fib_channel_0) end

fib_channel_100 = Channel(chan->fibonnaci_channel(chan, 0); ctype=Int, csize=100)
println("Channels csize=100: ")
@btime for i in 1:n take!(fib_channel_100) end