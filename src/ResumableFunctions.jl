"""
Main module for ResumableFunctions.jl – C# style generators a.k.a. semi-coroutines for Julia
"""
module ResumableFunctions

using MacroTools: striplines, @capture, flatten, postwalk, inexpr
using MacroTools: combinedef, splitdef, combinearg, splitarg

export @resumable, @yield, @nosave, @yieldfrom

include("safe_logging.jl")

include("types.jl")
include("transforms.jl")
include("utils.jl")
include("macro.jl")

end
