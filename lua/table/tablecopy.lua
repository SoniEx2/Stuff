local next,type,rawset,pcall = next,type,rawset,pcall

local gmt = debug and debug.getmetatable or getmetatable

local function trycopy(obj)
  local mt = gmt(obj)

  -- do we have a metatable? does it have a __copy method?
  if type(mt) == "table" and mt.__copy then
    -- try to call it (this supports __call-ables too)
    return pcall(mt.__copy, obj)
  else
    return false
  end
end

-- deepcopy for long tables
local function deep_mode1(inp,copies)
  -- in case you change the function name, change it here too
  local _self = deep_mode1

  local status, out = trycopy(inp)
  if status then
    return copy
  end

  if type(inp) ~= "table" then
    return inp
  end

  out = {}

  copies = type(copies) == "table" and copies or {}
  -- use normal assignment so we use copies' metatable (if any)
  copies[inp] = out

  -- skip metatables by using next directly
  for key, value in next, inp do
    rawset(out, key, copies[value] or _self(value, copies))
  end
  return out
end

local function check(obj, todo, copies)
  if copies[obj] ~= nil then
    return copies[obj]
  end
  local status, copy = trycopy(obj)
  if status then
    copies[obj] = copy
    return copy
  end
  if type(obj) == "table" then
    local t = {}
    todo[obj], copies[obj] = t, t
    return t
  end
  return obj
end

local function deep_mode2(inp, copies)
  local todo = {}
  local copies = type(copies) == "table" and copies or {}
  local out = check(inp, todo, copies)

  while next(todo) do        -- check todo for entries
    local i, o = next(todo)  -- get an entry
    todo[i] = nil            -- and clear it

    -- do a simple copy
    for k, v in next, i do
      rawset(o, k, check(v, todo, copies))
    end
  end

  return out
end

-- NB
local function shallow(inp)
  local out = {}
  for key, value in next, inp do -- skip metatables by using next directly
    out[key] = value
  end
  return out
end

-- set table.copy.shallow and table.copy.deep
-- we could also set the metatable so that calling it calls table.copy.deep
-- (or turn it into table.copy(table,deep) where deep is a boolean)
table.copy = {
  shallow = shallow,

  -- best for copying _G
  deep = deep_mode1,

  -- best for copying long chains
  deep_chain = deep_mode1,

  -- best for copying long tables
  deep_long = deep_mode2
}

-- ////////////
-- // ADDONS //
-- ////////////

-- START metatable deep copy
local mtdeepcopy_mt = {
  __newindex = function(t, k, v)
    setmetatable(v, gmt(k))
    rawset(t, k, v)
  end
}

table.copy.deep_keep_metatable = function(inp)
  return table.copy.deep(inp, setmetatable({}, mtdeepcopy_mt))
end
-- END metatable deep copy

-- START metatable shallow copy
local mtshallowcopy_mt = {
  __newindex = function(t, k, v) -- don't rawset() so that __index gets called
    setmetatable(v, gmt(k))
  end,
  __index = function(t, k)
    return k
  end
}

table.copy.shallow_keep_metatable = function(inp)
  return table.copy.deep(inp, setmetatable({}, mtshallowcopy_mt))
end
-- END metatable shallow copy
