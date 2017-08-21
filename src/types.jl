abstract type FiniteStateMachineIterator end

mutable struct BoxedUInt8
  n :: UInt8
end

(start(fsm_iter::T) :: UInt8) where T<:FiniteStateMachineIterator = fsm_iter._state

next(fsm_iter::T, state::UInt8) where T<:FiniteStateMachineIterator = fsm_iter(), fsm_iter._state

(done(fsm_iter::T, state::UInt8=0x00) :: Bool) where T<:FiniteStateMachineIterator = fsm_iter._state == 0xff