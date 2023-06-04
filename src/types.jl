"""
Abstract type used as base type for the type created by the `@resumable` macro.
"""
abstract type FiniteStateMachineIterator{R} end

"""
Mutable struct that contains a single `UInt8`.
"""
mutable struct BoxedUInt8
  n :: UInt8
end

"""
Implements the `iteratorsize` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
Base.IteratorSize(::Type{T}) where T<:FiniteStateMachineIterator = Base.SizeUnknown()

"""
Implements the `eltype` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
Base.eltype(::Type{T}) where T<:FiniteStateMachineIterator{R} where R = R

function Base.iterate(fsm_iter::FiniteStateMachineIterator)
  ret = generate(fsm_iter, nothing)
  ret isa IteratorReturn && return nothing
  ret
end

function Base.iterate(fsm_iter::FiniteStateMachineIterator, state)
  ret = generate(fsm_iter, nothing, state)
  ret isa IteratorReturn && return nothing
  ret
end
