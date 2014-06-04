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
