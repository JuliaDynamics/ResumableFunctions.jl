using ResumableFunctions
using Test

@resumable function test_type_parameters(::Type{Int}, start::Int)
  for i in start:start+3
    @yield i
  end
end

@resumable function test_type_parameters(::Type{Float64}, start::Int)
  for i in start:start+3
    @yield float(i)
  end
end

@testset "test_type_parameters" begin
  @test collect(test_type_parameters(Int, 1)) == [1, 2, 3, 4]
  @test collect(test_type_parameters(Float64, 1)) == [1.0, 2.0, 3.0, 4.0]
end

@resumable function test_type_parameters_order(start::Int, ::Type{T})::T where {T}
  for i in start:start+3
    @yield T(i)
  end
end

@testset "test_type_parameters_order" begin
  @test collect(test_type_parameters_order(1, Int)) == [1, 2, 3, 4]
  @test collect(test_type_parameters_order(1, Float64)) == [1.0, 2.0, 3.0, 4.0]
  @test typeof(first(test_type_parameters_order(1, ComplexF32))) == ComplexF32
end

@resumable function test_type_parameters_optional(start::Int; t::Type{T}=Type{Int})::T where {T}
  for i in start:start+3
    @yield T(i)
  end
end


@testset "test_type_parameters_optional" begin
  @test collect(test_type_parameters_optional(1, t=Int)) == [1, 2, 3, 4]
  @test collect(test_type_parameters_optional(1, t=Float64)) == [1.0, 2.0, 3.0, 4.0]
  @test typeof(first(test_type_parameters_optional(1, t=ComplexF32))) == ComplexF32
end
