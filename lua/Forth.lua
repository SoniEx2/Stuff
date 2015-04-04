-- Forth?

local w = {
  DUP = function(...) return ..., ... end,
  POP = function(...) return select(2, ...) end,
  SWAP = function(...) return select(2, ...),  ..., select(3, ...) end,
  ["."] = function(...) io.write(tostring((...)),"\n") return select(2, ...) end,
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
    -- native code
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

-- tests
do
  -- define "square"
  w["square"] = {
    w["DUP"],
    w["*"]
  }
  local p = {
    5,
    w["square"],
    w["DUP"],
    w["."]
  }
  assert(vm(p, 1) == 25)
end

do
  -- calculate a * 3 + a, where a = 2
  local p = {
    w["DUP"],
    3,
    w["*"],
    w["+"],
    w["DUP"],
    w["."]
  }
  assert(vm(p, 1, 2) == 8)
end

do
  -- define native word
  w["^"] = function(...)
    return select(2, ...) ^ ..., select(3, ...)
  end
  local p = {
    2,
    3,
    w["^"],
    w["DUP"],
    w["."]
  }
  assert(vm(p, 1) == 8)
end