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
(start(fsm_iter::T) :: UInt8) where T<:FiniteStateMachineIterator = fsm_iter._state

"""
Implements the `next` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
next(fsm_iter::T, state::UInt8) where T<:FiniteStateMachineIterator = fsm_iter(), fsm_iter._state

"""
Implements the `done` method of the *iterator* interface for a subtype of `FiniteStateMachineIterator`.
"""
(done(fsm_iter::T, state::UInt8=0x00) :: Bool) where T<:FiniteStateMachineIterator = fsm_iter._state == 0xff