using ResumableFunctions
using Test
using JuliaLowering, JuliaSyntax

using ResumableFunctions: Binding, is_boxed, resolve_bindings, bindings_named, substitute_markers

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

@testset "markers survive lowering" begin
  ex = quote
    function f()
      a = 1
      let a = a + 1
        @yield a
      end
      @nosave t = g()
      t
    end
  end
  ctx, tree, bindings = resolve_bindings(@__MODULE__, substitute_markers(ex))
  rendered = string(tree)
  @test occursin("yield_marker", rendered)
  @test occursin("nosave_marker", rendered)
  @test length(bindings_named(bindings, :a)) == 2
  @test length(bindings_named(bindings, :t)) == 1
end

using ResumableFunctions: slot_bindings, ScopeTracker, scoping

function tracker_slot_counts(mod, body, args)
  scope = ScopeTracker(0, mod, [Dict(a => a for a in args)])
  renamed = scoping(deepcopy(body), scope)
  seen = Dict{Symbol,Set{Symbol}}()
  walk(x) =
    if x isa Symbol && occursin(r"_\d+$", String(x))
      push!(get!(seen, Symbol(replace(String(x), r"_\d+$" => "")), Set{Symbol}()), x)
    elseif x isa Expr
      foreach(walk, x.args)
    end
  walk(renamed)
  foreach(a -> push!(get!(seen, a, Set{Symbol}()), a), args)
  Dict(k => length(v) for (k, v) in seen)
end

function lowered_slot_counts(mod, body, args)
  fn = Expr(:function, Expr(:call, :f, args...), body)
  Dict(k => length(v) for (k, v) in slot_bindings(mod, fn))
end

@testset "slot counts agree with the current scoper" begin
  cases = [
    "straight line"  => (:(begin; x = 1; y = x + 1; y end), Symbol[]),
    "shadowing let"  => (:(begin; a = 3; b = 2; let a = b, b = a; (a, b) end end), Symbol[]),
    "nested let"     => (:(begin; a = 1; let a = 2; let a = 3; a end end end), Symbol[]),
    "for loop"       => (:(begin; s = 0; for i in 1:3; s += i end; s end), Symbol[]),
    "while loop"     => (:(begin; n = 0; while n < 3; n += 1 end; n end), Symbol[]),
    "reassignment"   => (:(begin; q = 1; q = 2; q = 3; q end), Symbol[]),
    "comprehension"  => (:(begin; c = 1; z = [i * c for i in 1:5]; z end), Symbol[]),
    "filtered comprehension" => (:(begin; z = [i for i in 1:10 if i < 5]; z end), Symbol[]),
    "argument shadowed by let" => (:(begin; let p = p + 1; p end end), [:p]),
    "a = a"          => (:(begin; a = a; a = a + 1; a end), Symbol[]),
  ]
  for (label, (body, args)) in cases
    @test tracker_slot_counts(@__MODULE__, body, args) ==
          lowered_slot_counts(@__MODULE__, body, args)
  end
end

@testset "slot counts differ only for bindings needing no slot" begin
  body = :(begin; try; u = 1; catch e; v = 2; finally; w = 3 end end)
  tracker = tracker_slot_counts(@__MODULE__, body, Symbol[])
  lowered = lowered_slot_counts(@__MODULE__, body, Symbol[])
  @test !haskey(tracker, :e)
  @test lowered[:e] == 1
  @test filter(p -> first(p) !== :e, lowered) == tracker

  body = :(begin; k = 1; g = n -> n * k; g(2) end)
  tracker = tracker_slot_counts(@__MODULE__, body, Symbol[])
  lowered = lowered_slot_counts(@__MODULE__, body, Symbol[])
  @test !haskey(tracker, :n)
  @test lowered[:n] == 1
  @test filter(p -> first(p) !== :n, lowered) == tracker
end
