using MacroTools: flatten

function getslots(func_def::Dict) :: Dict{Symbol, Type}
  slots = Dict{Symbol, Type}()
  func_name = gensym()
  func_def[:name] = func_name
  eval(combinedef(func_def |> flatten))
  code_data_infos = @eval code_typed($func_name)
  (code_info, data_type) = code_data_infos[1]
  for (i, slotname) in enumerate(code_info.slotnames)
    slots[slotname] = code_info.slottypes[i]
  end
  delete!(slots, Symbol("#temp#"))
  delete!(slots, Symbol("#unused#"))
  delete!(slots, Symbol("#self#"))
  slots
end
