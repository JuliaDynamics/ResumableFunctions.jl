"""
Abstract type used as base type for the type created by the `@resumable` macro.
"""
abstract type FiniteStateMachineIterator end

"""
Mutable struct that contains a single `UInt8`.
"""
mutable struct BoxedUInt8
  n :: UInt8
end

"""
Implements the `start` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
function Base.start(fsm_iter::T) where T<:FiniteStateMachineIterator 
  fsm_iter._state  = 0x00
  fsm_iter()
end

"""
Implements the `next` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
function Base.next(fsm_iter::T, state) where T<:FiniteStateMachineIterator
  state, fsm_iter()
end
"""
Implements the `done` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
(Base.done(fsm_iter::T, state) :: Bool) where T<:FiniteStateMachineIterator = fsm_iter._state == 0xff

"""
Implements the `iteratorsize` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
Base.IteratorSize(::Type{T}) where T<:FiniteStateMachineIterator = Base.SizeUnknown()