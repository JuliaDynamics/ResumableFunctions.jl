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

function Base.iterate(fsm_iter::T, state::UInt8=0x00) where T<:FiniteStateMachineIterator
  fsm_iter._state = state
  result = fsm_iter()
  fsm_iter._state == 0xff && return nothing
  result, fsm_iter._state
end