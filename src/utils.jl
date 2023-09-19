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

function forward_args(func_def)
  args = []
  map!(func_def[:args], func_def[:args]) do arg
    name, type, splat, default = splitarg(arg)
    name = something(name, gensym())
    if splat
      push!(args, :($name...))
    else
      push!(args, name)
    end
    combinearg(name, type, splat, default)
  end
  kwargs = []
  for arg in func_def[:kwargs]
    name, type, splat, default = splitarg(arg)
    if splat
      push!(kwargs, :($name...))
    else
      push!(kwargs, name)
    end
  end
  args, kwargs
end

const unused = (Symbol("#temp#"), Symbol("_"), Symbol(""), Symbol("#unused#"), Symbol("#self#"))

"""
Function returning the slots of a function definition
"""
function get_slots(func_def::Dict, args::Dict{Symbol, Any}, mod::Module)
  slots = Dict{Symbol, Any}()
  func_def[:name] = gensym()
  func_def[:args] = (func_def[:args]..., func_def[:kwargs]...)
  func_def[:kwargs] = []
  # replace yield with inference barrier
  func_def[:body] = postwalk(transform_yield, func_def[:body])
  # collect items to skip
  nosaves = Set{Symbol}()
  func_def[:body] = postwalk(x->transform_nosave(x, nosaves), func_def[:body])
  # eval function
  func_expr = combinedef(func_def) |> flatten
  @eval(mod, @noinline $func_expr)
  # get typed code
  codeinfos = @eval(mod, code_typed($(func_def[:name]), Tuple; optimize=false))
  # extract slot names and types
  for codeinfo in codeinfos
    for (name, type) in collect(zip(codeinfo.first.slotnames, codeinfo.first.slottypes))
      name ∉ nosaves && name ∉ unused && (slots[name] = Union{type, get(slots, name, Union{})})
    end
  end
  # remove `catch exc` statements
  postwalk(x->remove_catch_exc(x, slots), func_def[:body])
  # set error branches to Any
  for (key, val) in slots
    if val === Union{}
      slots[key] = Any
    end
  end
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

# this is similar to code_typed but it considers the world age
function code_typed_by_type(@nospecialize(tt::Type);
                            optimize::Bool=true,
                            world::UInt=Base.get_world_counter(),
                            interp::Core.Compiler.AbstractInterpreter=Core.Compiler.NativeInterpreter(world))
    tt = Base.to_tuple_type(tt)
    # look up the method
    match, valid_worlds = Core.Compiler.findsup(tt, Core.Compiler.InternalMethodTable(world))
    meth = Base.func_for_method_checked(match.method, tt, match.sparams)
    # run inference, normally not allowed in generated functions
    frame = Core.Compiler.typeinf_frame(interp, meth, match.spec_types, match.sparams, optimize)
    frame === nothing && error("inference failed")
    return frame.linfo, frame.src, valid_worlds
end

function fsmi_generator(world::UInt, source::LineNumberNode, passtype, fsmitype::Type{Type{T}}, fargtypes) where T
    @nospecialize
    # get typed code of the inference function evaluated in get_slots
    # but this time with concrete argument types
    tt = Base.to_tuple_type(fargtypes)
    mi, ci, valid_worlds = code_typed_by_type(tt; world, optimize=false)
    (; min_world, max_world) = valid_worlds
    # extract slot types
    cislots = Dict(zip(ci.slotnames, ci.slottypes))
    slots = map(fieldnames(T)[2:end]) do slot
      s = get(cislots, slot, Any)
      Core.Compiler.widenconst(s)
    end
    # generate code to instantiate the concrete type
    stub = Core.GeneratedFunctionStub(identity, Core.svec(:pass, :fsmi, :fargs), Core.svec())
    if isempty(slots)
      exprs = stub(world, source, :(return $T()))
    else
      exprs = stub(world, source, :(return $T{$(slots...)}()))
    end
    # lower codeinfo to pass world age and invalidation edges
    ci = ccall(:jl_expand_and_resolve, Any, (Any, Any, Any), exprs, passtype.name.module, Core.svec())
    ci.min_world = min_world
    ci.max_world = max_world
    ci.edges = Core.MethodInstance[mi]
    return ci
end

# JuliaLang/julia#48611: world age is exposed to generated functions, and should be used
if VERSION >= v"1.10.0-DEV.873"
  # This is like @generated, but it receives the world age of the caller
  # which we need to do inference safely and correctly
  @eval function typed_fsmi(fsmi, fargs...)
      $(Expr(:meta, :generated_only))
      $(Expr(:meta, :generated, fsmi_generator))
  end
else
  # runtime fallback function
  function typed_fsmi(fsmi::Type{T}, fargs...)::T where T
    slots = fieldtypes(fsmi)[2:end]
    if isempty(slots)
      return T()
    else
      return T{slots...}()
    end
  end
end