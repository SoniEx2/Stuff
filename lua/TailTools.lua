local M = {}

do -- range(from, to, increment)
  local function _recursiverange(i,b,c,...)
    if c > 0 and i > b then
      return ...
    elseif c < 0 and i <= b then
      return ...
    end
    -- we're adding things to the start of ..., so ... is backwards
    -- this is why we need the wrapper/abstraction below
    -- NO we CAN NOT use "..., i" here, because the Lua reference
    -- manual says "..., i" keeps only the first thing on ... and
    -- drops everything else
    return _recursiverange(i+c,b,c,i,...)
  end
  
  function M.recursiverange(a,b,c)
    -- because range(1,3,1) is 1, 2, 3, not 3, 2, 1.
    return _recursiverange(b,a,-(c or 1))
  end
end

do -- recursivedeepcopy(originalTable, recursionTable, copyKeys)
  local function _recursivedeepcopy(ot, nt, r, ck, k)
    nt = nt or {}
    r = r or {}
    -- debug line
    --print(ot,nt,r,ck,k)
    if r[ot] == nil then
      r[ot] = nt
    end
    local nk, v = next(ot, k)
    if nk == nil then
      return nt
    end
    if ck and type(nk) == "table" then
      k = nk
      nk = r[nk] or _recursivedeepcopy(nk, {}, r, ck)
    end
    if type(v) == "table" then
      v = r[v] or _recursivedeepcopy(v, {}, r, ck)
    end
    rawset(nt, nk, v)
    return _recursivedeepcopy(ot, nt, r, ck, k)
  end
  function M.recursivedeepcopy(t, r, ck)
    return _recursivedeepcopy(t, {}, r, ck)
  end
end

do -- recursiveshallowcopy(originalTable)
  local function _recursiveshallowcopy(ot, nt, k)
    nt = nt or {}
    -- debug line
    --print(ot,nt,k)
    local nk, v = next(ot, k)
    if nk == nil then
      return nt
    end
    rawset(nt, nk, v)
    return _recursiveshallowcopy(ot, nt, nk)
  end
  function M.recursiveshallowcopy(t)
    return _recursiveshallowcopy(t, {})
  end
end

do -- recursiveprinttable(table)
  local function escape(str)
    local type_of_str = type(str)
    if type_of_str == "table" or type_of_str == "function" or type_of_str == "userdata" then
      return tostring(str)
    end
    str = ("%q"):format(str)
    -- backslash-newline to backslash-n
    str = str:gsub("\\\n","\\n")
    return str
  end
  local function _recursiveprinttable(t, k, s)
    -- debug line
    --print(t,k)
    local nk, v = next(t, k)
    if nk == nil then
      return s:sub(1,-3)
    end
    s = (s or "") .. string.format("[%s]=(%s), ",escape(nk),escape(v))
    return _recursiveprinttable(t, nk, s)
  end
  function M.recursiveprinttable(t)
    return "{" .. _recursiveprinttable(t) .. "}"
  end
end

do -- recursiveprettyprint(object)
  local function stuffa(r, c, v)
    local x = r[v]
    if not x then
      local tv = type(v)
      if tv == "table" then
        c["table"] = (c["table"] or 0) + 1
        r[v] = "T" .. c["table"]
      elseif tv == "userdata" then
        c["ud"] = (c["ud"] or 0) + 1
        r[v] = "U" .. c["ud"]
      elseif tv == "function" then
        c["function"] = (c["function"] or 0) + 1
        r[v] = "F" .. c["function"]
      elseif tv == "thread" then
        c["thread"] = (c["thread"] or 0) + 1
        r[v] = "C" .. c["thread"]
      elseif tv == "string" then
        if v:match("^[A-Za-z_][A-Za-z0-9_]*$") then
          return v
        end
      end
      x = "[" .. (r[v] or string.format("%q", v):gsub("\\\n","\\n")) .. "]"
    end
    return x
  end
  local function stuffb(r, c, v)
    local x = r[v]
    if not x then
      local tv = type(v)
      if tv == "table" then
        c["table"] = (c["table"] or 0) + 1
        r[v] = "T" .. c["table"]
      elseif tv == "userdata" then
        c["ud"] = (c["ud"] or 0) + 1
        r[v] = "U" .. c["ud"]
      elseif tv == "function" then
        c["function"] = (c["function"] or 0) + 1
        r[v] = "F" .. c["function"]
      elseif tv == "thread" then
        c["thread"] = (c["thread"] or 0) + 1
        r[v] = "C" .. c["thread"]
      end
      x = r[v] or string.format("%q", v):gsub("\\\n","\\n")
    end
    return x
  end
  local function _recursiveprinttable(t, r, c, k, s)
    -- debug line
    --print(t,k)
    r = r or {}
    c = c or {}
    local nk, v = next(t, k)
    if nk == nil then
      return s:sub(1,-3)
    end
    s = (s or "") .. string.format("%s = %s, ", stuffa(r, c, nk), stuffb(r, c, v))
    return _recursiveprinttable(t, r, c, nk, s)
  end
  function M.recursiveprettyprint(t)
    if type(t) == "table" then
      local r,c = {},{}
      r[t] = "T1"
      c["table"] = 1
      return "T1{" .. _recursiveprinttable(t, r, c) .. "}"
    else
      return stuffb(t, {}, {})
    end
  end
end

do -- recursiveprettyprint2(object)
  local stuffa,_recursiveprettyprint,stufftype
  stufftype = function(v, r, c)
    local x = r[v]
    if not x then
      local tv = type(v)
      if tv == "table" then
        c["table"] = (c["table"] or 0) + 1
        x = "T" .. c["table"]
        r[v] = x
        return x .. _recursiveprinttable(v, r, c)
      elseif tv == "function" then
        c["function"] = (c["function"] or 0) + 1
        x = "F" .. c["function"]
      elseif tv == "userdata" then
        c["ud"] = (c["ud"] or 0) + 1
        x = "U" .. c["ud"]
      elseif tv == "thread" then
        c["thread"] = (c["thread"] or 0) + 1
        x = "C" .. c["thread"]
      end
      r[v] = x
    end
    return x or string.format("%q", v):gsub("\\\n","\\n")
  end
  stuffa = function(v, r, c)
    local tv = type(v)
    if tv == "string" then
      if v:match("^[A-Za-z_][A-Za-z0-9_]*$") then
        return v
      end
    end
    return "[" .. stufftype(v, r, c) .. "]"
  end
  function _recursiveprinttable(t, r, c, k, s)
    -- debug line
    --print(t,k)
    r = r or {}
    c = c or {}
    s = s or ""
    local nk, v = next(t, k)
    if nk == nil then
      return "{ " .. s:sub(1,-3) .. " }"
    end
    s = s .. string.format("%s = %s, ", stuffa(nk, r, c), stufftype(v, r, c))
    return _recursiveprinttable(t, r, c, nk, s)
  end
  function M.recursiveprettyprint2(t)
    return stufftype(t, {}, {})
  end
end

return M
