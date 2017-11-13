"""
Function returning the name of an argument expression
"""
function get_arg_name(expr) :: Symbol
  @capture(expr, arg_::arg_type_=val_) && return arg
  @capture(expr, arg_=val_) && return arg
  @capture(expr, arg_::arg_type_) && return arg
  @capture(expr, arg_) && return arg
end

"""
Function returning the names of the where parameters
"""
function get_param_name(expr) :: Symbol
  @capture(expr, arg_<:arg_type_) && return arg
  @capture(expr, arg_) && return arg
end

"""
Function returning the slots of a function definition
"""
function get_slots(func_def::Dict, mod) :: Dict{Symbol, Type}
  slots = Dict{Symbol, Type}()
  func_def[:name] = gensym()
  func_expr = combinedef(func_def) |> flatten
  @eval(mod, $func_expr)
  code_data_infos = @eval(mod, code_typed($(func_def[:name])))
  (code_info, data_type) = code_data_infos[1]
  for (i, slotname) in enumerate(code_info.slotnames)
    slots[slotname] = code_info.slottypes[i]
  end
  postwalk(x->remove_catch_exc(x, slots), func_def[:body])
  postwalk(x->make_arg_any(x, slots), func_def[:body])
  delete!(slots, Symbol("#temp#"))
  delete!(slots, Symbol("#unused#"))
  delete!(slots, Symbol("#self#"))
  slots
end

"""
Function removing the `exc` symbol of a `catch exc` statement of a list of slots.
"""
function remove_catch_exc(expr, slots::Dict{Symbol, Type})
  @capture(expr, (try body__ catch exc_; handling__ end) | (try body__ catch exc_; handling__ finally always__ end)) && delete!(slots, exc)
  expr
end

"""
Function changing the type of a slot `arg` of a `arg = @yield ret` or `arg = @yield` statement to `Any`.
"""
function make_arg_any(expr, slots::Dict{Symbol, Type})
  @capture(expr, (arg_ = @yield ret_) | (arg_ = @yield)) || return expr
  slots[arg] = Any
  expr
end
