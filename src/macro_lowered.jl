using JuliaLowering
using JuliaSyntax

macro resumable(ex)
    # 1. Parse using JuliaSyntax
    st = JuliaSyntax.parsestmt(JuliaLowering.SyntaxTree, string(ex))
    
    # 2. Lower
    lowered = JuliaLowering.lower(__module__, st)
    code = JuliaLowering.to_lowered_expr(lowered)
    
    # 3. Extract CodeInfo
    ci = nothing
    if code.head === :thunk && code.args[1] isa Core.CodeInfo
        for stmt in code.args[1].code
            if stmt isa Expr && stmt.head === :method && length(stmt.args) >= 3 && stmt.args[3] isa Core.CodeInfo
                ci = stmt.args[3]
                break
            end
        end
    end
    if ci === nothing
        error("Could not lower to method CodeInfo")
    end
    
    # 4. Generate the struct and stepping function from CodeInfo
    # (Proof of concept)
    return quote
        println("Resumable FSM generated from JuliaLowering CodeInfo!")
    end
end
