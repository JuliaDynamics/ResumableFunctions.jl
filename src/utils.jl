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

# adapted from Base
function code_typed_by_type(@nospecialize(tt::Type);
                            optimize::Bool=true,
                            debuginfo::Symbol=:default,
                            world::UInt=Base.get_world_counter(),
                            interp::Core.Compiler.AbstractInterpreter=Core.Compiler.NativeInterpreter(world))
    if isdefined(Base, :IRShow)
        debuginfo = Base.IRShow.debuginfo(debuginfo)
    elseif debuginfo === :default
        debuginfo = :source
    end
    if debuginfo !== :source && debuginfo !== :none
        throw(ArgumentError("'debuginfo' must be either :source or :none"))
    end
    tt = Base.to_tuple_type(tt)
    min_world = Ref{UInt}(typemin(UInt))
    max_world = Ref{UInt}(typemax(UInt))
    matches = Base._methods_by_ftype(tt, nothing, #=lim=#-1, world, false, min_world, max_world, Ptr{Int32}(C_NULL))::Vector
    match = only(matches)::Core.MethodMatch
    meth = Base.func_for_method_checked(match.method, tt, match.sparams)
    (code, ty) = Core.Compiler.typeinf_code(interp, meth, match.spec_types, match.sparams, optimize)
    if code === nothing
        ast = meth
    else
        debuginfo === :none && Base.remove_linenums!(code)
        ast = code
    end
    mi = ccall(:jl_specializations_get_linfo, Ref{Core.MethodInstance},
            (Any, Any, Any), match.method, match.spec_types, match.sparams)
    return mi, ast, min_world[], max_world[]
end

function fsmi_generator(world::UInt, source::LineNumberNode, passtype, fsmitype, fargtypes)
    @nospecialize
    tt = Base.to_tuple_type(fargtypes)
    mi, ci, min_world, max_world = code_typed_by_type(tt; world, optimize=false)
    cislots = Dict(zip(ci.slotnames, ci.slottypes))
    slots = [cislots[arg] for arg in fieldnames(only(fsmitype.parameters))[2:end]]
    stub = Core.GeneratedFunctionStub(identity, Core.svec(:pass, :fsmi, :fargs), Core.svec())
    exprs = stub(world, source, :(return fsmi{$(slots...)}()))
    ci = ccall(:jl_expand_and_resolve, Any, (Any, Any, Any), exprs, passtype.name.module, Core.svec())
    ci.min_world = min_world
    ci.max_world = max_world
    ci.edges = Core.MethodInstance[mi]
    return ci
end

@eval function typed_fsmi(fsmi, fargs...)
    $(Expr(:meta, :generated_only))
    $(Expr(:meta, :generated, fsmi_generator))
end