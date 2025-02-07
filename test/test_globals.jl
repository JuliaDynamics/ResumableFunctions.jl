using ResumableFunctions
using Test

a = 1
g() = 1
h(x) = x+1

@resumable function f1()
    b = a
    b = b+1
    @yield b
end

@test collect(f1()) == [2]

@resumable function f2()
    a = a
    a = a+1
    @yield a
end

@test collect(f2()) == [2]

@resumable function f3()
    g = g()
    g = g+1
    @yield g
end

@test collect(f3()) == [2]

@resumable function f4()
    a = h(a)
    a = a+1
    @yield a
end

@test collect(f4()) == [3]

@resumable function f5()
    g = h(g())
    g = g+1
    @yield g
end

@test collect(f5()) == [3]
