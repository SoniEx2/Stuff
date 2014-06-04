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
  
  function recursiverange(a,b,c)
    -- because range(1,3,1) is 1, 2, 3, not 3, 2, 1.
    return _recursiverange(b,a,-(c or 1))
  end
end

do -- recursivecopy(originalTable, recursionTable, copyKeys)
  local function _recursivecopy(ot, nt, r, ck, k)
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
      nk = r[nk] or _recursivecopy(nk, {}, r, ck)
    end
    if type(v) == "table" then
      v = r[v] or _recursivecopy(v, {}, r, ck)
    end
    rawset(nt, nk, v)
    return _recursivecopy(ot, nt, r, ck, nk)
  end
  function recursivecopy(t, r, ck)
    return _recursivecopy(t, {}, r, ck)
  end
end
