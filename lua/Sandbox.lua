-- "Advanced" Lua Sandbox

local rawget, getmetatable, type, ipairs, error, pcall, setmetatable, pairs = rawget, getmetatable, type, ipairs, error, pcall, setmetatable, pairs
local crunning = coroutine.running

local threadset = setmetatable({}, {__mode="v"})
local original = {}

-- no metatable
local TAG_NONE = {}

local superMt = {}

-- dummy table
local tEmpty = {}

local function getSandboxMt(obj)
  local co = crunning() -- feature: no special handling for the main coroutine/thread
  local mt = (threadset[co] or tEmpty)[type(obj)] or original[type(obj)] or getmetatable(obj) -- fallback to native Lua
  if mt == TAG_NONE then pcall(io.write,mt) return nil end
  if mt == superMt then pcall(io.write,mt) return nil end
  pcall(io.write,mt)
  return mt
end

local function getHandler(obj, evt)
  return rawget(getSandboxMt(obj) or tEmpty, evt)
end

local function genBinOpMtAccessor(event)
  return function(op1, op2, ...)
    local v = getHandler(op1, event) or getHandler(op2, event)
    if v ~= nil then
      return v(op1, op2, ...)
    else
      error("attempt to perform " .. event .. " on a " .. type(op1) .. " and a " .. type(op2), 2)
    end
  end
end

-- operators that can be handled by genBinOpMtAccessor
-- note that "le" cannot be handled by genBinOpMtAccessor
local binOps = {"add","sub","mul","div","mod","pow","concat","idiv","band","bor","bxor","shl","shr","lt"}
local binOpsAccessors = {}
for i,v in ipairs(binOps) do
  binOpsAccessors["__"..v] = genBinOpMtAccessor("__"..v)
end

local function genUnOpMtAccessor(event)
  return function(op, ...)
    local v = getHandler(op, event)
    if v ~= nil then
      return v(op, ...)
    else
      error("attempt to perform " .. event .. " on a " .. type(op) .. " value", 2)
    end
  end
end

-- operators that can be handled by genUnOpMtAccessor
local unOps = {"unm", "len", "bnot"}
local unOpsAccessors = {}
for i,v in ipairs(unOps) do
  unOpsAccessors["__"..v] = genUnOpMtAccessor("__"..v)
end

-- operators that don't need handling
local unhandledOps = {"eq"}

-- "le to lt coercion" might change in future Lua versions. this check provides compatibility with those versions.
local ltToLe = pcall(function() return setmetatable({}, {__lt=function() return true end}) <= 0 end)
-- "le" operator
local function leHandler(op1, op2)
  local v = getHandler(op1, "__le") or getHandler(op2, "__le")
  if v ~= nil then
    return v(op1, op2)
  elseif ltToLe then
    -- special handling needed for "assume a <= b is equivalent to not (b < a)"
    -- this behavior might change in future Lua versions (see above)
    local v = getHandler(op1, "__lt") or getHandler(op2, "__lt")
    if v ~= nil then
      return not v(op2, op1)
    else
      error("attempt to compare " .. type(op1) .. " with " .. type(op2), 2)
    end
  else
    error("attempt to compare " .. type(op1) .. " with " .. type(op2), 2)
  end
end

-- "index" operator
local function indexHandler(op, idx)
  local v = getHandler(op, "__index")
  if v == nil then
    error("attempt to index a " .. type(op) .. " value", 2)
  end
  if type(v) == "function" then
    return v(op, idx)
  else
    return v[idx]
  end
end

-- "newindex" operator
local function newindexHandler(op, idx, newv)
  local v = getHandler(op, "__newindex")
  if v == nil then
    error("attempt to index a " .. type(op) .. " value", 2)
  end
  if type(v) == "function" then
    v(op, idx, newv)
  else
    v[idx] = newv
  end
end

-- "call" operator
local function callHandler(op, ...)
  local v = getHandler(op, "__call")
  if type(v) == "function" then
    v(op, idx, newv)
  end
  error("attempt to call a " .. type(op) .. " value", 2)
end

-- inject sandbox functions
local objects = {
  "", -- string
  0, -- number
  function() end, -- function
  coroutine.create(function() end), -- thread
  -- table
  -- (heavy) userdata
  false, -- boolean
  -- nil
}

superMt.__index = indexHandler
superMt.__newindex = newindexHandler
superMt.__call = callHandler
superMt.__le = leHandler
for k,v in pairs(binOpsAccessors) do
  superMt[k] = v
end
for k,v in pairs(unOpsAccessors) do
  superMt[k] = v
end

local globals = _ENV or _G

local dgmt,dsmt = debug.getmetatable,debug.setmetatable

local initted = false

local tostring = tostring

local function init()
  if initted then error("attempt to initialize already initialized sandbox", 2) end
  initted = true
  for i=1,#objects+1 do
    local v = objects[i]
    original[type(v)] = dgmt(v)
    dsmt(v, superMt)
  end
  globals.getmetatable = function(obj)
    local mt = getSandboxMt(obj)
    if mt and rawget(mt, "__metatable") ~= nil then
      return rawget(mt, "__metatable")
    end
    return mt
  end
  globals.tostring = function(obj)
    local mt = getSandboxMt(obj)
    if mt and rawget(mt, "__tostring") ~= nil then
      return (rawget(mt, "__tostring")(obj))
    end
    -- ugh >.>
    local oldmt = debug.getmetatable(obj)
    debug.setmetatable(obj, nil)
    local v = tostring(obj)
    debug.setmetatable(obj, oldmt)
    return v
  end
end

local function restore()
  if not initted then error("attempt to restore uninitialized sandbox") end
  initted = false
  for i=1,#objects+1 do
    local v = objects[i]
    dsmt(v, original[type(v)])
  end
  globals.getmetatable = getmetatable
  globals.tostring = tostring
end

local corobox = {}

do
  local cocreate, coresume, corunning, costatus, cowrap, coyield = coroutine.create, coroutine.resume, coroutine.running, coroutine.status, coroutine.wrap, coroutine.yield
  local function create(f)
    local co = cocreate(f)
    threadset[co] = {}
    for k,v in pairs(threadset[corunning()] or tEmpty) do
      threadset[co][k] = v
    end
    return co
  end
  local function wrap(f)
    local fco = cowrap(function() -- heh :3
        threadset[corunning()] = {}
        return f(coyield(corunning()))
      end)
    local co = fco()
    for k,v in pairs(threadset[corunning()] or tEmpty) do
      threadset[co][k] = v
    end
    return fco
  end
  corobox.create = create
  corobox.wrap = wrap
end

return {
  init = init,
  restore = restore,
  corobox = corobox,
  TAG_NONE = TAG_NONE,
  _threadset = threadset,
  _original = original,
  registerHook = function(event, handler)
    -- when called, handler can use getLocalMetatable to get the local metatable.
    -- ps: use of this method is discouraged
    superMt[event] = handler
  end,
  setLocalMetatable = function(thread, object, mt)
    -- must only be called between an init() and a corresponding restore()
    if dgmt(object) ~= superMt then
      return false, "Invalid object"
    else
      if not threadset[thread] then -- there's no way to know what to inherit here, so we use this instead
        threadset[thread] = {}
        for k,v in pairs(original) do
          threadset[thread][k] = v
        end
      end
      threadset[thread][type(object)] = mt
      return true
    end
  end,
  getLocalMetatable = function(thread, object)
    -- must only be called between an init() and a corresponding restore()
    if dgmt(object) ~= superMt then
      return nil, "Invalid object"
    else
      return (threadset[thread] or tEmpty)[type(object)]
    end
  end
}