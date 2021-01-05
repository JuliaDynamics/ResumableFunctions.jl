"""
Function returning the name of a where parameter
"""
function get_param_name(expr) :: Symbol
  @capture(expr, arg_<:arg_type_) && return arg
  @capture(expr, arg_) && return arg
end

"""
Function returning the arguments of a function definition
"""
function get_args(func_def::Dict)
  arg_dict = Dict{Symbol, Any}()
  arg_list = Vector{Symbol}()
  kwarg_list = Vector{Symbol}()
  for arg in (func_def[:args]...,)
    arg_def = splitarg(arg)
    push!(arg_list, arg_def[1])
    arg_dict[arg_def[1]] = arg_def[3] ? Any : arg_dict[arg_def[1]] = arg_def[2]
  end
  for arg in (func_def[:kwargs]...,)
    arg_def = splitarg(arg)
    push!(kwarg_list, arg_def[1])
    arg_dict[arg_def[1]] = arg_def[3] ? Any : arg_dict[arg_def[1]] = arg_def[2]
  end
  arg_list, kwarg_list, arg_dict
end

"""
Function returning the slots of a function definition
"""
function get_slots(func_def::Dict, args::Dict{Symbol, Any}, mod::Module) :: Dict{Symbol, Any}
  slots = Dict{Symbol, Any}()
  func_def[:name] = gensym()
  func_def[:args] = (func_def[:args]..., func_def[:kwargs]...)
  func_def[:kwargs] = []
  body = func_def[:body]
  func_def[:body] = postwalk(transform_yield, func_def[:body])
  nosaves = Set{Symbol}()
  func_def[:body] = postwalk(x->transform_nosave(x, nosaves), func_def[:body])
  func_expr = combinedef(func_def) |> flatten
  @eval(mod, @noinline $func_expr)
  codeinfos = @eval(mod, code_typed($(func_def[:name])))
  for codeinfo in codeinfos
    for (name, type) in collect(zip(codeinfo.first.slotnames, codeinfo.first.slottypes))
      name ∉ nosaves && (slots[name] = type)
    end
  end
  for (argname, argtype) in args
    slots[argname] = argtype
  end
  postwalk(x->remove_catch_exc(x, slots), func_def[:body])
  postwalk(x->make_arg_any(x, slots), body)
  for (key, val) in slots
    if val === Union{}
      slots[key] = Any
    end
  end
  delete!(slots, Symbol("#temp#"))
  delete!(slots, Symbol("_"))
  delete!(slots, Symbol(""))
  delete!(slots, Symbol("#unused#"))
  delete!(slots, Symbol("#self#"))
  slots
end

"""
Function removing the `exc` symbol of a `catch exc` statement of a list of slots.
"""
function remove_catch_exc(expr, slots::Dict{Symbol, Any})
  @capture(expr, (try body__ catch exc_; handling__ end) | (try body__ catch exc_; handling__ finally always__ end)) && delete!(slots, exc)
  expr
end

"""
Function changing the type of a slot `arg` of a `arg = @yield ret` or `arg = @yield` statement to `Any`.
"""
function make_arg_any(expr, slots::Dict{Symbol, Any})
  @capture(expr, arg_ = ex_) || return expr
  _is_yield(ex) || return expr
  slots[arg] = Any
  expr
end

"""
Function checking the use of a return statement with value
"""
function hasreturnvalue(expr)
  @capture(expr, return val_) || return expr
  (val === :nothing || val === nothing) && return expr
  @warn "@resumable function contains return statement with value!"
  expr
end
