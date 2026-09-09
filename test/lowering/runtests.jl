using ResumableFunctions
using Test
using JuliaLowering, JuliaSyntax

using ResumableFunctions: Binding, is_boxed, resolve_bindings, bindings_named

bindings_of(ex) = last(resolve_bindings(@__MODULE__, ex))
named(ex, name) = bindings_named(bindings_of(ex), name)

@testset "shadowing in let" begin
  ex = quote
    function f()
      a = 3
      b = 2
      let a = b, b = a
        (a, b)
      end
    end
  end
  @test length(named(ex, :a)) == 2
  @test length(named(ex, :b)) == 2
  @test all(b -> b.kind === :local, named(ex, :a))
end

@testset "arguments and globals" begin
  ex = quote
    function f(x)
      y = x + undefined_global
      y
    end
  end
  bs = bindings_of(ex)
  @test only(bindings_named(bs, :x)).kind === :argument
  @test only(bindings_named(bs, :y)).kind === :local
  @test only(bindings_named(bs, :undefined_global)).kind === :global
end

@testset "a = a is one local that is not always defined" begin
  ex = quote
    function f()
      a = a
      a = a + 1
      a
    end
  end
  b = only(named(ex, :a))
  @test b.kind === :local
  @test b.n_assigned == 2
  @test !b.is_always_defined
end

@testset "named tuple field names are not bindings" begin
  ex = quote
    function bar()
      foo = "unused"
      vec = (foo = 3,)::@NamedTuple{foo::Int64}
      vec
    end
  end
  @test length(named(ex, :foo)) == 1
end

@testset "boxed captures" begin
  mutated = quote
    function f()
      c = 1
      x = [i * c for i in 1:5]
      c += 1
      (x, [i * c for i in 1:5])
    end
  end
  b = only(named(mutated, :c))
  @test b.is_captured
  @test b.n_assigned == 2
  @test is_boxed(b)

  fixed = quote
    function f()
      c = 1
      [i * c for i in 1:5]
    end
  end
  b = only(named(fixed, :c))
  @test b.is_captured
  @test !is_boxed(b)
end
