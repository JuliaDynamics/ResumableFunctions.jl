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
    if arg_def[1] != nothing
      push!(arg_list, arg_def[1])
      arg_dict[arg_def[1]] = arg_def[3] ? Any : arg_dict[arg_def[1]] = arg_def[2]
    end
  end
  for arg in (func_def[:kwargs]...,)
    arg_def = splitarg(arg)
    push!(kwarg_list, arg_def[1])
    arg_dict[arg_def[1]] = arg_def[3] ? Any : arg_dict[arg_def[1]] = arg_def[2]
  end
  arg_list, kwarg_list, arg_dict
end

const unused = (Symbol("#temp#"), Symbol("_"), Symbol(""), Symbol("#unused#"), Symbol("#self#"))

"""
Function returning the slots of a function definition
"""
function get_slots(func_def::Dict, args::Dict{Symbol, Any}, mod::Module)
  func_def[:name] = gensym()
  func_def[:args] = (func_def[:args]..., func_def[:kwargs]...)
  func_def[:kwargs] = []
  func_def[:body] = postwalk(transform_yield, func_def[:body])
  nosaves = Set{Symbol}()
  func_def[:body] = postwalk(x->transform_nosave(x, nosaves), func_def[:body])
  func_expr = combinedef(func_def) |> flatten
  @eval(mod, @noinline $func_expr)
  codeinfos = @eval(mod, code_typed($(func_def[:name]), Tuple; optimize=false))
  slots = only(codeinfos).first.slotnames
  filter!(x->x ∉ nosaves && x ∉ unused, slots)
  return func_def[:name], slots
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

struct IteratorReturn{T}
  value :: T
  IteratorReturn(value) = new{typeof(value)}(value)
end

@inline function generate(fsm_iter::FiniteStateMachineIterator, send, state=nothing)
  #fsm_iter._state = state
  result = fsm_iter(send)
  fsm_iter._state === 0xff && return IteratorReturn(result)
  result, nothing
end

@inline function generate(iter, _)
  ret = iterate(iter)
  isnothing(ret) && return IteratorReturn(nothing)
  ret
end

@inline function generate(iter, _, state)
  ret = iterate(iter, state)
  isnothing(ret) && return IteratorReturn(nothing)
  ret
end

# copied from Base
function code_typed_by_type(@nospecialize(tt::Type);
                            optimize::Bool=true,
                            debuginfo::Symbol=:default,
                            world::UInt=Base.get_world_counter(),
                            interp::Core.Compiler.AbstractInterpreter=Core.Compiler.NativeInterpreter(world))
    # (ccall(:jl_is_in_pure_context, Bool, ()) || world == typemax(UInt)) &&
    #     error("code reflection cannot be used from generated functions")
    if isdefined(Base, :IRShow)
        debuginfo = Base.IRShow.debuginfo(debuginfo)
    elseif debuginfo === :default
        debuginfo = :source
    end
    if debuginfo !== :source && debuginfo !== :none
        throw(ArgumentError("'debuginfo' must be either :source or :none"))
    end
    tt = Base.to_tuple_type(tt)
    matches = Base._methods_by_ftype(tt, #=lim=#-1, world)::Vector
    asts = []
    for match in matches
        match = match::Core.MethodMatch
        meth = Base.func_for_method_checked(match.method, tt, match.sparams)
        (code, ty) = Core.Compiler.typeinf_code(interp, meth, match.spec_types, match.sparams, optimize)
        if code === nothing
            push!(asts, meth => Any)
        else
            debuginfo === :none && Base.remove_linenums!(code)
            push!(asts, code => ty)
        end
    end
    return asts
end

function fsmi_generator(world::UInt, source::LineNumberNode, passtype, fsmitype, fargtypes)
    @nospecialize passtype fsmitype fargtypes
    tt = Base.to_tuple_type(fargtypes)
    ci = first(only(code_typed_by_type(tt; world, optimize=false)))
    cislots = Dict(zip(ci.slotnames, ci.slottypes))
    slots = [cislots[arg] for arg in fieldnames(only(fsmitype.parameters))[2:end]]
    stub = Core.GeneratedFunctionStub(identity, Core.svec(:pass, :fsmi, :fargs), Core.svec())
    return stub(world, source, :(return fsmi{$(slots...)}()))
end

@eval function typed_fsmi(fsmi, fargs...)
    $(Expr(:meta, :generated_only))
    $(Expr(:meta, :generated, fsmi_generator))
end