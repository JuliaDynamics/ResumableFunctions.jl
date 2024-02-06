using Test
using ResumableFunctions

# From issue #86

##

@resumable function singleton()::String
    @yield "anything"
end

# 1. must be defined before combined!
@resumable function _empty(x)::String
end

@resumable function combined()::String
    for s in singleton()
        @yield s # fails "here" because s is determined to be of type Nothing because of the second loop
    end
    # 2. must reuse of variable
    for s in _empty(1) # dummy argument needed to illustrate point 1.
        @yield s
    end
end

@test collect(combined()) == ["anything"]
@test collect(combined()) isa Vector{String}

##

@resumable function singletonF()::String
    @yield "anything"
end

@resumable function _emptyF()::String
end

@resumable function combinedF()::String
    # @yieldfrom also uses the same variable names for each generated loop
    @yieldfrom singletonF()
    @yieldfrom _emptyF()
end

@test collect(combinedF()) == ["anything"]
@test collect(combinedF()) isa Vector{String}
