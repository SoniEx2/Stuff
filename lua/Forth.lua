-- Forth?

local w = {
  DUP = function(...) return ..., ... end,
  POP = function(...) return select(2, ...) end,
  SWAP = function(...) return select(2, ...),  ..., select(3, ...) end,
  ["."] = function(...) print((...)) return select(2, ...) end,
  ["+"] = function(...) return select(2, ...) + ..., select(3, ...) end,
  ["-"] = function(...) return select(2, ...) - ..., select(3, ...) end,
  ["*"] = function(...) return select(2, ...) * ..., select(3, ...) end,
  ["/"] = function(...) return select(2, ...) / ..., select(3, ...) end,
}
local function vm(word, idx, ...)
  if type(word) ~= "table" then error("table expected") end
  local _type = type(word[idx])
  local tco = word[idx + 1] == nil
  if _type == "table" then
    -- definition
    if tco then return vm(word[idx], 1, ...) end
    return vm(word, idx + 1, vm(word[idx], 1, ...))
  elseif _type == "function" then
    -- builtin
    if tco then return word[idx](...) end
    return vm(word, idx + 1, word[idx](...))
  elseif _type == "number" then
    -- number
    if tco then return word[idx], ... end
    return vm(word, idx + 1, word[idx], ...)
  elseif _type == "nil" then
    -- end of word / "EXIT"
    return ...
  end
end

-- 2 DUP 3 * + .
-- w["."](w["+"](w["*"](3, w["DUP"](2))))
local p = {
  2,
  w["DUP"],
  3,
  w["*"],
  w["+"],
  w["."]
}
vm(p, 1)