local sb = require"Sandbox"

local print = print

sb.init()

local co = sb.corobox.create(function()
    getmetatable("").__add = function(a,b) return a .. b end
    assert("a"+"b" == "ab")
  end)
local copy = {}
for k,v in pairs(getmetatable"") do
  copy[k] = v
end
sb.setLocalMetatable(co, "", copy)
coroutine.resume(co)
assert(not pcall(function() print("a"+"b") end))

assert(copy.__add)

sb.restore() -- restore normal behavior

assert(not pcall(function() print("a"+"b") end))