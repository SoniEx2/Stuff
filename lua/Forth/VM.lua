-- Forth VM?

local function vm(word, i, ...)
  if type(word) ~= "table" then error("table expected") end
  local _type = type(word[i])
  local tco = word[i + 1] == nil
  if _type == "table" then
    -- definition
    if tco then return vm(word[i], 1, ...) end
    return vm(word, i + 1, vm(word[i], 1, ...))
  elseif _type == "function" then
    -- native code
    return vm(word[i](word, i + 1, ...))
  elseif _type == "number" or _type == "string" then
    -- literal
    return vm(word, i + 1, word[i], ...)
  elseif _type == "nil" then
    -- end of word / "EXIT"
    return ...
  end
end

return {vm=vm, run=function(w, ...) return vm(w, 1, ...) end}