using ResumableFunctions
using Test
using MacroTools: postwalk

before = :(function f(arg, arg2::Int)
        @yield arg
        for i in 1:10
            let i=i
                @yield arg2
                arg2 = arg2 + i
            end
        end
        while true
            try
                @yield arg2
                arg2 = arg2 + 1
            catch e
                @yield e
                arg2 = arg2 + 1
            end
            break
        end
        arg2+arg
        @yield arg2
    end
)

after = eval(quote @macroexpand @resumable $before end)

function get_all_linenodes(expr)
    nodes = Set()
    postwalk(expr) do x
        if x isa LineNumberNode
            push!(nodes, x)
        end
        x
    end
    return nodes
end

@testset "all line numbers are preserved" begin
@test get_all_linenodes(before) ⊆ get_all_linenodes(after)
end
