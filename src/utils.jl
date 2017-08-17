function getslots(expr::Expr, name::Symbol) :: Dict{Symbol, Type}
  slots = Dict{Symbol, Type}()
  eval(expr)
  code_data_infos = @eval code_typed($name)
  for (code_info, data_type) in code_data_infos
    for i in 2:length(code_info.slotnames)
      slots[code_info.slotnames[i]] = code_info.slottypes[i]
    end
  end
  delete!(slots, Symbol("#temp#"))
  delete!(slots, Symbol("#unused#"))
  slots
end
