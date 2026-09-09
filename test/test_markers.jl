using ResumableFunctions
using Test

using ResumableFunctions: substitute_markers, yield_marker, yieldfrom_marker, nosave_marker

ref(name) = GlobalRef(ResumableFunctions, name)

@testset "marker substitution" begin
  @test substitute_markers(:(@yield a))        == Expr(:call, ref(:yield_marker), :a)
  @test substitute_markers(:(@yield))          == Expr(:call, ref(:yield_marker))
  @test substitute_markers(:(@yieldfrom itr))  == Expr(:call, ref(:yieldfrom_marker), :itr)
  @test substitute_markers(:(@nosave x = f())) == Expr(:(=), :x, Expr(:call, ref(:nosave_marker), :(f())))
end

@testset "substitution leaves everything else alone" begin
  @test substitute_markers(:(@inbounds a[1])) == :(@inbounds a[1])
  @test substitute_markers(:(a + b))          == :(a + b)
  @test substitute_markers(:x)                == :x
  @test substitute_markers(1)                 == 1
end

@testset "substitution reaches nested expressions" begin
  ex = quote
    for i in 1:3
      @yield i
    end
  end
  @test !occursin("@yield", string(substitute_markers(ex)))
  @test occursin("yield_marker", string(substitute_markers(ex)))
end

@testset "markers are never called" begin
  @test isempty(methods(yield_marker))
  @test isempty(methods(yieldfrom_marker))
  @test isempty(methods(nosave_marker))
end

@testset "the macros still error outside a resumable function" begin
  @test_throws "@yield macro outside a @resumable function!"     @macroexpand @yield 1
  @test_throws "@yieldfrom macro outside a @resumable function!" @macroexpand @yieldfrom 1
  @test_throws "@nosave macro outside a @resumable function!"    @macroexpand @nosave x = 1
end
