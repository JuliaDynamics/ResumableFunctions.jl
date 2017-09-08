# Copy of utility functions from MacroTools (master)
# Can be removed once a new version of MacroTools is released

using MacroTools: @q, striplines, @match, @capture

isshortdef(ex) = (@capture(ex, (fcall_ = body_)) &&
                  (@capture(gatherwheres(fcall)[1],
                            (f_(args__) |
                             f_(args__)::rtype_))))

function longdef1(ex)
  if @capture(ex, (arg_ -> body_))
    @q function ($arg,) $body end
  elseif isshortdef(ex)
    @assert @capture(ex, (fcall_ = body_))
    striplines(Expr(:function, fcall, body))
  else
    ex
  end
end

function shortdef1(ex)
  @match ex begin
    function f_(args__) body_ end => @q $f($(args...)) = $body
    function f_(args__)::rtype_ body_ end => @q $f($(args...))::$rtype = $body
    function (args__,) body_ end => @q ($(args...),) -> $body
    ((args__,) -> body_) => ex
    (arg_ -> body_) => @q ($arg,) -> $body
    _ => ex
  end
end

""" `gatherwheres(:(f(x::T, y::U) where T where U)) => (:(f(x::T, y::U)), (:U, :T))`
"""
function gatherwheres(ex)
  if @capture(ex, (f_ where {params1__}))
    f2, params2 = gatherwheres(f)
    (f2, (params1..., params2...))
  else
    (ex, ())
  end
end

doc"""    splitdef(fdef)
Match any function definition
```julia
function name{params}(args; kwargs)::rtype where {whereparams}
   body
end
```
and return `Dict(:name=>..., :args=>..., etc.)`. The definition can be rebuilt by
calling `MacroTools.combinedef(dict)`, or explicitly with
```
rtype = get(dict, :rtype, :Any)
all_params = [get(dict, :params, [])..., get(dict, :whereparams, [])...]
:(function $(dict[:name]){$(all_params...)}($(dict[:args]...);
                                            $(dict[:kwargs]...))::$rtype
      $(dict[:body])
  end)
```
"""
function splitdef(fdef)
  error_msg = "Not a function definition: $fdef"
  @assert(@capture(longdef1(fdef),
                   function (fcall_ | fcall_) body_ end),
          "Not a function definition: $fdef")
  fcall_nowhere, whereparams = gatherwheres(fcall)
  @assert(@capture(fcall_nowhere, ((func_(args__; kwargs__)) |
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


"""
    combinedef(dict::Dict)
`combinedef` is the inverse of `splitdef`. It takes a splitdef-like Dict
and returns a function definition. 
  """
function combinedef(dict::Dict)
  rtype = get(dict, :rtype, :Any)
  params = get(dict, :params, [])
  wparams = get(dict, :whereparams, [])
  name = dict[:name]
  name_param = isempty(params) ? name : :($name{$(params...)})
  # We need the `if` to handle parametric inner/outer constructors like
  # SomeType{X}(x::X) where X = SomeType{X}(x, x+2)
  if isempty(wparams)
    :(function $name_param($(dict[:args]...);
                           $(dict[:kwargs]...))::$rtype
      $(dict[:body])
      end)
  else
    :(function $name_param($(dict[:args]...);
                           $(dict[:kwargs]...))::$rtype where {$(wparams...)}
      $(dict[:body])
      end)
  end
end