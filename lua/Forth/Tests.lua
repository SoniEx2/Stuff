local w = require"Words".words
local vm = require"VM".vm
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
  w["^"] = function(i, ...)
    return i, select(2, ...) ^ ..., select(3, ...)
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

--[[
-- requires an OS that supports /dev/null
do
  local f = io.open("/dev/null", "w")
  local p = {
    2, 3, w["*"], w["DUP"], function(i, ...) f:write(tostring((...)),"\n") return i, select(2, ...) end
  }
  -- LuaJIT optimizes the vm() into a simple f:write("6", ...)
  for i=1,10000 do
    assert(vm(p, 1))
  end
  f:close()
end
--]]

do
  local loop = {
    w["SWAP"],
    3,
    w["*"],
    w["SWAP"],
    1,
    w["-"],
    w["DUP"],
    0,
    w["="],
    w["NIF2"],
    nil, -- placeholder
    nil, -- TCO
    w["DROP"] -- remove loop count from stack
  }
  loop[11] = loop
  local p = {
    3, -- initial value
    3, -- loop count
    loop,
    w["DUP"],
    w["."]
  }
  assert(vm(p, 1) == 81)
end

do
  local s = "Hi!\n"
  local p = {}
  for i=1, #s do
    p[i] = w.EMIT
  end
  vm(p, 1, string.byte(s, 1, -1))
end

-- TODO: vm({2, 3, w["2>R"], w["2R@"], w["2R>"], w["."], w["."], w["."], w["."]}, 1) -> prints "3 2 3 2 "