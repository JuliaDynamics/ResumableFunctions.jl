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
  for arg in (func_def[:args]..., func_def[:kwargs]...)
    arg_def = splitarg(arg)
    push!(arg_list, arg_def[1])
    arg_dict[arg_def[1]] = arg_def[3] ? Tuple : arg_dict[arg_def[1]] = arg_def[2]
  end
  arg_list, arg_dict
end

"""
Function returning the slots of a function definition
"""
function get_slots(func_def::Dict, args::Dict{Symbol, Any}, mod::Module) :: Dict{Symbol, Any}
  slots = Dict{Symbol, Any}()
  func_def[:name] = gensym()
  func_def[:args] = (func_def[:args]..., func_def[:kwargs]...)
  func_def[:kwargs] = []
  func_def[:body] = postwalk(yieldtoreturn, func_def[:body])
  func_expr = combinedef(func_def) |> flatten |> MacroTools.striplines
  @eval(mod, @noinline $func_expr)
  code_data_infos = @eval(mod, code_typed($(func_def[:name]); optimize=false))
  for (code_info, data_type) in code_data_infos
    for (i, slotname) in enumerate(code_info.slotnames)
      slots[slotname] = code_info.slottypes[i]
    end
  end
  for (argname, argtype) in args
    slots[argname] = argtype
  end
  postwalk(x->remove_catch_exc(x, slots), func_def[:body])
  postwalk(x->make_arg_any(x, slots), func_def[:body])
  delete!(slots, Symbol("#temp#"))
  delete!(slots, Symbol("#unused#"))
  delete!(slots, Symbol("#self#"))
  slots
end

"""
Function returning whether an expression is a `@yield` macro
"""
_is_yield(ex) = false

function _is_yield(ex::Expr)
  return ex.head == :macrocall && ex.args[1] == Symbol("@yield")
end

"""
Function to transform a `@yield` statement to a `return` statement
"""
function yieldtoreturn(expr)
  _is_yield(expr) || return expr
  ret = length(expr.args) > 2 ? expr.args[3:end] : [nothing]
  quote
    return $(ret...)
  end
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
  @capture(expr, (arg_ = @yield ret_) | (arg_ = @yield)) || return expr
  slots[arg] = Any
  expr
end


"""
Function returning the args for the type construction.
"""
function make_args(func_def::Dict)
  args=[]
  for arg in (func_def[:args]..., func_def[:kwargs]...)
    arg_def = splitarg(arg)
    push!(args, combinearg(arg_def[1], arg_def[2], false, arg_def[4]))
  end
  (args...,)
end