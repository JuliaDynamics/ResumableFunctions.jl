using Test
using ResumableFunctions

## Issue 69

function f()
    i = 1
    let j=i
        val = j
    end
    return val
end
f()

##

@resumable function g1()
    i = 1
    let j=i
        val=j
    end
    @yield val
end

@test_throws UndefVarError collect(g1())

##

@resumable function g2()
    i = 1
    @yield val
end
@test_throws UndefVarError collect(g2())

## Issue 70
function f2()
    let j
        j = 1
    end
end

@resumable function f3()
    let j
        j = 1
    end
end

@resumable function f4()
    let i=1, j=2
        i+j
    end
end

@resumable function f5()
    i=1
    j=2
    let i=i, j=j
        i+j
    end
end
