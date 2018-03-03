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
Implements the `start` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
function Base.start(fsm_iter::T) where T<:FiniteStateMachineIterator
  fsm_iter._state  = 0x00
  #fsm_iter()
end

"""
Implements the `next` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
function Base.next(fsm_iter::T, state::UInt8) where T<:FiniteStateMachineIterator
  fsm_iter._result, fsm_iter._state
end

"""
Implements the `done` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
function (Base.done(fsm_iter::T, state::UInt8=0x00) :: Bool) where T<:FiniteStateMachineIterator
  try
    fsm_iter._result = fsm_iter()
  end
  fsm_iter._state == 0xff
end

"""
Implements the `iteratorsize` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
Base.iteratorsize(::Type{T}) where T<:FiniteStateMachineIterator = Base.SizeUnknown()

"""
Implements the `eltype` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
Base.eltype(::Type{T}) where T<:FiniteStateMachineIterator{R} where R = R