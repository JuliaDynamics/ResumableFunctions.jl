isdefined(Base, :__precompile__) && __precompile__()

"""
Main module for ResumableFunctions.jl – C# style generators for Julia
"""
module ResumableFunctions

  import Base.start, Base.next, Base.done

  export @resumable, @yield


  include("macrotoolutils.jl")
  include("utils.jl")
  include("transforms.jl")
  include("types.jl")
  include("macro.jl")
end
