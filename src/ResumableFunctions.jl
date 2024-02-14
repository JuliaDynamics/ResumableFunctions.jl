"""
Main module for ResumableFunctions.jl – C# style generators a.k.a. semi-coroutines for Julia
"""
module ResumableFunctions

  using MacroTools
  using MacroTools: combinedef, combinearg, flatten, postwalk

  export @resumable, @yield, @nosave, @yieldfrom

  function __init__()
    STDERR_HAS_COLOR[] = get(stderr, :color, false)
  end

  include("safe_logging.jl")

  include("types.jl")
  include("transforms.jl")
  include("utils.jl")
  include("macro.jl")
end
