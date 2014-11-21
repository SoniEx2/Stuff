local next,type,rawset = next,type,rawset

local gmt = debug and debug.getmetatable or getmetatable

-- deepcopy for long tables
local function deep_mode1(inp,copies)
  if type(gmt(inp)) == "table" and gmt(inp).__copy then
    local c = gmt(inp).__copy(inp)
    if copies then copies[inp] = c end
    return c
  elseif type(inp) ~= "table" then
    return inp
  end
  local out = {}
  copies = (type(copies) == "table") and copies or {}
  copies[inp] = out -- use normal assignment so we use copies' metatable (if any)
  for key,value in next,inp do -- skip metatables by using next directly
    -- we want a copy of the key and the value
    -- if one is not available on the copies table, we have to make one
    -- we can't do normal assignment here because metatabled copies tables might set metatables
    
    -- out[copies[key] or deep(key,copies)]=copies[value] or deep(value,copies)
    rawset(out,copies[key] or deep_mode1(key,copies),copies[value] or deep_mode1(value,copies))
  end
  return out
end

-- deepcopy for long chains
local function check(obj, todo, copies)
  if copies[obj] ~= nil then
    return copies[obj]
  elseif type(gmt(obj)) == "table" and gmt(obj).__copy then
    local c = gmt(obj).__copy(obj)
    copies[obj] = c
    return c
  elseif type(obj) == "table" then
    local t = {}
    todo[obj] = t
    copies[obj] = t
    return t
  end
  return obj
end
local function deep_mode2(inp, copies)
  if type(gmt(inp)) == "table" and gmt(inp).__copy then
    return gmt(inp).__copy(inp)
  end
  local out, todo = {}, {}
  copies = copies or {}
  todo[inp], copies[inp] = out, out

  -- we can't use pairs() here because we modify todo
  while next(todo) do
    local i, o = next(todo)
    todo[i] = nil
    for k, v in next, i do
      rawset(o, check(k, todo, copies), check(v, todo, copies))
    end
  end
  return out
end


local function shallow(inp)
  local out = {}
  for key,value in next,inp do -- skip metatables by using next directly
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
  __newindex = function(t,k,v)
    setmetatable(v,debug.getmetatable(k))
    rawset(t,k,v)
  end
}

table.copy.deep_keep_metatable = function(inp)
  return table.copy.deep(inp,setmetatable({},mtdeepcopy_mt))
end
-- END metatable deep copy

-- START metatable shallow copy
local mtshallowcopy_mt = {
  __newindex = function(t,k,v) -- don't rawset() so that __index gets called
    setmetatable(v,debug.getmetatable(k))
  end,
  __index = function(t,k)
    return k
  end
}

table.copy.shallow_keep_metatable = function(inp)
  return table.copy.deep(inp,setmetatable({},mtshallowcopy_mt))
end
-- END metatable shallow copy
