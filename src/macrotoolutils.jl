# Copy of utility functions from MacroTools (master)
# Can be removed once new version of MacroTools is released

using MacroTools: striplines, @match, @capture, prewalk

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
