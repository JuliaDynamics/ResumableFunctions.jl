# Copy of utility functions from MacroTools (master)
# Can be removed once new version of MacroTools is released

using MacroTools: striplines, @match, @capture

macro q(ex)
  Expr(:quote, striplines(ex))
end

function longdef1(ex)
  @match ex begin
    (f_(args__) = body_) => @q function $f($(args...)) $body end
    (f_(args__)::rtype_ = body_) => @q function $f($(args...))::$rtype $body end
    ((args__,) -> body_) => @q function ($(args...),) $body end
    (arg_ -> body_) => @q function ($arg,) $body end
    (f_(args__) where {whereparams__} = body_) =>
        @q function $f($(args...)) where {$(whereparams...)}
            $body end
    ((f_(args__)::rtype_) where {whereparams__} = body_) =>
        @q function ($f($(args...))::$rtype) where {$(whereparams...)}
            $body end
    _ => ex
  end
end

function splitdef(fdef)
  error_msg = "Not a function definition: $fdef"
  @assert(@capture(longdef1(fdef),
                   function ((fcall_ where {whereparams__}) | fcall_)
                   body_ end),
          error_msg)
  @assert(@capture(fcall, ((func_(args__; kwargs__)) |
                           (func_(args__; kwargs__)::rtype_) |
                           (func_(args__)) |
                           (func_(args__)::rtype_))),
          error_msg)
  @assert(@capture(func, (fname_{params__} | fname_)), error_msg)
  di = Dict(:name=>fname, :args=>args,
            :kwargs=>(kwargs===nothing ? [] : kwargs), :body=>body)
  if rtype !== nothing; di[:rtype] = rtype end
  if whereparams !== nothing; di[:whereparams] = whereparams end
  if params !== nothing; di[:params] = params end
  di
end

function combinedef(dict::Dict)
    rtype = get(dict, :rtype, :Any)
    # We have to combine params and whereparams because f{}() where {} = 0 is
    # a syntax error unless as a constructor.
    all_params = [get(dict, :params, [])..., get(dict, :whereparams, [])...]
    :(function $(dict[:name]){$(all_params...)}($(dict[:args]...);
                                                $(dict[:kwargs]...))::$rtype
          $(dict[:body])
      end)
end

function splitarg(arg_expr)
  splitvar(arg) =
      @match arg begin
          ::T_ => (nothing, T)
          name_::T_ => (name::Symbol, T)
          x_ => (x::Symbol, :Any)
      end
  (is_splat = @capture(arg_expr, arg_expr2_...)) || (arg_expr2 = arg_expr)
  if @capture(arg_expr2, arg_ = default_)
      @assert default !== nothing "splitarg cannot handle `nothing` as a default. Use a quoted `nothing` if possible. (MacroTools#35)"
      return (splitvar(arg)..., is_splat, default)
  else
      return (splitvar(arg_expr2)..., is_splat, nothing)
  end
end

function combinearg(arg_name, arg_type, is_splat, default)
  a = arg_name===nothing ? :(::$arg_type) : :($arg_name::$arg_type)
  a2 = is_splat ? Expr(:..., a) : a
  return default === nothing ? a2 : Expr(:kw, a2, default)
end