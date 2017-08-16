-- workarounds for IDE bugs
local squote = "'"
local dquote = '"'
local backslash = "\\"

local function chartopad(c)
  return string.format("\\%03d", string.byte(c))
end

local pads = {
  z = "\\z",
  x = "\\x",
  ['0'] = '\\0',
  ['1'] = '\\1',
  ['2'] = '\\2',
  ['3'] = '\\3',
  ['4'] = '\\4',
  ['5'] = '\\5',
  ['6'] = '\\6',
  ['7'] = '\\7',
  ['8'] = '\\8',
  ['9'] = '\\9',

  -- remap escape sequences
  a = chartopad('\a'),
  b = chartopad('\b'),
  f = chartopad('\f'),
  r = chartopad('\r'),
  n = chartopad('\n'),
  t = chartopad('\t'),
  v = chartopad('\v'),
  [ dquote ] = chartopad(dquote),
  [ squote ] = chartopad(squote),
  [ backslash ] = chartopad(backslash),
  ['\n'] = chartopad('\n')
}

local pads53 = {}
for k,v in pairs(pads) do pads53[k] = v end
pads53.u = "\\u"

local numbers = {
  ['0'] = true,
  ['1'] = true,
  ['2'] = true,
  ['3'] = true,
  ['4'] = true,
  ['5'] = true,
  ['6'] = true,
  ['7'] = true,
  ['8'] = true,
  ['9'] = true
}

local findpairs
do
  local function _findnext(flags, index)
    -- only branch if index = 0
    if index > 0 then
      -- this should always give a match,
      -- as we're starting from the same index as the returned match
      -- TODO: test %f >.>
      local x,y = string.find(flags[1], flags[2], index, flags[3])
      return string.find(flags[1], flags[2], y+1, flags[3])
    else
      return string.find(flags[1], flags[2], index + 1, flags[3])
    end
  end
  function findpairs(str, pat, raw)
    return _findnext, {str, pat, raw}, 0
  end
end

local function getline(str, pos)
  -- remove everything that's not a newline then count the newlines + 1
  return #(string.gsub(string.sub(str, 1, math.max(pos - 1, 0)), "[^\n]", "")) + 1
end

-- Parse a string like it's a Lua 5.2 string.
local function parseString52(s)
  -- "validate" string
  local startChar = string.sub(s,1,1)
  if startChar~=squote and startChar~=dquote then
    error("not a string", 0)
  end
  if string.sub(s, -1, -1) ~= startChar then
    error(("[%s]:%d: unfinished string"):format(s, getline(s, -1)), 0)
  end

  -- remove quotes
  local str = string.sub(s, 2, -2)

  -- replace "normal" escapes with a padded escape
  str = string.gsub(str, "()\\(.)", function(idx,c)
      return pads[c] or
      error(("[%s]:%d: invalid escape sequence near '\\%s'"):format(s, getline(s, idx), c), 0)
    end)

  -- check for non-escaped startChar
  do
    local idx = string.find(str, "[" .. startChar .. "\n]")
    if idx then
      error(("[%s]:%d: unfinished string"):format(s, getline(s, idx - 1)), 0)
    end
  end

  -- pad numerical escapes
  str = string.gsub(str, "\\([0-9])(.?)(.?)", function(a, b, c)
      local x = a
      -- swap b and c if #b == 0; this is to avoid UB:
      -- _in theory_ `c` could match but not `b`, this solves
      -- that problem. uncomment if you know what you're doing.
      if #b == 0 then b, c = c, b end
      if numbers[b] then
        x, b = x .. b, ""
        if numbers[c] then
          x, c = x .. c, ""
        end
      end
      return backslash .. ("0"):rep(3 - #x) .. x .. b .. c
    end)

  local t = {}
  local i = 1
  local last = 1
  -- split on \z
  -- we can look for "\z" directly because we already escaped everything else
  for from, to in findpairs(str, "\\z", true) do
    t[i] = string.sub(str, last, from - 1)
    last = to+1
    i = i + 1
  end
  t[i] = string.sub(str, last)

  -- parse results
  local nt = {}
  local bpos = 0 -- TODO fix newline handling
  for x,y in ipairs(t) do
    -- fix "\x" and "\xn"
    if y:sub(-3):find("\\x", 1, true) then
      -- append 2 startChars, this'll error anyway so it doesn't matter.
      y = y .. startChar .. startChar
    end
    nt[x] = string.gsub(y, "()\\(([x0-9])((.).))",
      function(idx,a,b,c,d)
        if b ~= "x" then
          local n = tonumber(a)
          if n >= 256 then
            error(("[%s]:%d: decimal escape too large near '\\%s'"):format(s,getline(s,bpos+idx),a), 0)
          end
          return string.char(n)
        else
          local n = tonumber(c, 16)
          if n then
            return string.char(n)
          end
          local o = d:find("[0-9a-fA-F]") and c or d
          error(("[%s]:%d: hexadecimal digit expected near '\\x%s'"):format(s,getline(s,bpos+idx),o), 0)
        end
      end)
    if x > 1 then
      -- handle \z
      nt[x] = string.gsub(nt[x], "^[%s]*", "")
    end
    bpos = bpos + #y
  end
  -- merge
  return table.concat(nt, "")
end

-- Parse a string like it's a Lua 5.3 string.
local function parseString53(s)
  -- "validate" string
  local startChar = string.sub(s,1,1)
  if startChar~=squote and startChar~=dquote then
    error("not a string", 0)
  end
  if string.sub(s, -1, -1) ~= startChar then
    error(("[%s]:%d: unfinished string"):format(s, getline(s, -1)), 0)
  end

  -- remove quotes
  local str = string.sub(s, 2, -2)

  -- replace "normal" escapes with a padded escape
  str = string.gsub(str, "()\\(.)", function(idx,c)
      return pads53[c] or
      error(("[%s]:%d: invalid escape sequence near '\\%s'"):format(s, getline(s, idx), c), 0)
    end)

  -- check for non-escaped startChar
  do
    local idx = string.find(str, "[" .. startChar .. "\n]")
    if idx then
      error(("[%s]:%d: unfinished string"):format(s, getline(s, idx - 1)), 0)
    end
  end

  -- pad numerical escapes
  str = string.gsub(str, "\\([0-9])(.?)(.?)", function(a, b, c)
      local x = a
      -- swap b and c if #b == 0; this is to avoid UB:
      -- _in theory_ `c` could match but not `b`, this solves
      -- that problem. uncomment if you know what you're doing.
      if #b == 0 then b, c = c, b end
      if numbers[b] then
        x, b = x .. b, ""
        if numbers[c] then
          x, c = x .. c, ""
        end
      end
      return backslash .. ("0"):rep(3 - #x) .. x .. b .. c
    end)

  local t = {}
  local i = 1
  local last = 1
  -- split on \z
  -- we can look for "\z" directly because we already escaped everything else
  for from, to in findpairs(str, "\\[uz]", false) do
    t[i] = string.sub(str, last, from - 1)
    last = from
    i = i + 1
  end
  t[i] = string.sub(str, last)

  -- parse results
  local nt = {}
  local bpos = 0 -- TODO fix newline handling
  for x,y in ipairs(t) do
    -- fix "\x" and "\xn"
    if y:sub(-3):find("\\x", 1, true) then
      -- append 2 startChars, this'll error anyway so it doesn't matter.
      y = y .. startChar .. startChar
    end
    nt[x] = string.gsub(y, "()\\(([x0-9])((.).))",
      function(idx,a,b,c,d)
        if b ~= "x" then
          local n = tonumber(a)
          if n >= 256 then
            error(("[%s]:%d: decimal escape too large near '\\%s'"):format(s,getline(s,bpos+idx),a), 0)
          end
          return string.char(n)
        else
          local n = tonumber(c, 16)
          if n then
            return string.char(n)
          end
          local o = d:find("[0-9a-fA-F]") and c or d
          error(("[%s]:%d: hexadecimal digit expected near '\\x%s'"):format(s,getline(s,bpos+idx),o), 0)
        end
      end)
    if x > 1 then
      -- handle \z
      nt[x] = string.gsub(nt[x], "^\\z[%s]*", "")
      if nt[x]:sub(1,2) == "\\u" then
        if nt[x]:sub(3,3) ~= "{" then
          error(("[%s]:%d: missing '{' near '\\u'"):format(s,getline(s,bpos+3)), 0)
        end
        local mt, l = nt[x]:match("^\\u{([0-9a-fA-F]+}?)()")
        if not mt then
          error(("[%s]:%d: hexadecimal digit expected near '\\u{'"):format(s,getline(s,bpos+4)), 0)
        end
        if mt:sub(-1,-1) ~= "}" then
          error(("[%s]:%d: missing '}' near '\\u{%s'"):format(s,getline(s,bpos+l),mt), 0)
        end
        mt = mt:sub(1,-2) -- remove }
        if #mt > 6 or tonumber(mt, 16) > 1114111 then
          error(("[%s]:%d: UTF-8 value too large near '\\u{%s'"):format(s,getline(s,bpos+l),mt), 0)
        end
        local n = tonumber(mt, 16)
        local unicoded
        if n < 128 then
          unicoded = string.char(n)
        elseif n < 2048 then
          local low = (n % 64) + 128
          local high = math.floor(n / 64) + 192
          unicoded = string.char(high, low)
        elseif n < 0x10000 then
          local low = (n % 64) + 128
          local med = (math.floor(n/64) % 64) + 128
          local high = math.floor(n/64/64) + 224
          unicoded = string.char(high, med, low)
        else
          local low = (n % 64) + 128
          local med = (math.floor(n/64) % 64) + 128
          local high = (math.floor(n/64/64) % 64) + 128
          local higher = math.floor(n/64/64/64) + 240
          unicoded = string.char(higher, high, med, low)
        end
      end
    end
    bpos = bpos + #y
  end
  -- merge
  return table.concat(nt, "")
end

-- "tests"
-- TODO add more
-- also add automatic checks
if _VERSION == "Lua 5.2" and not ... then
  -- test string parsing
  local t = {
    [=["\""]=],
    [=["\32"]=],
    [=["\256"]=],
    [=["\xnn"]=],
    '"\\\n"',
    [=["\x"]=],
    [=["\xn"]=],
    [=['\x']=],
    [=['\x0']=],
    [=['   \\z\
    \x']=],
    [=['\\z
    ']=],
    [=['
    ']=]
  }
  for _, str in ipairs(t) do
    local s, m = pcall(parseString52, str)
    io.write(tostring(s and ("[" .. m .. "]") or "nil"))
    io.write(tostring(s and "" or ("\t" .. m)) .. "\n")
    s, m = load("return " .. str, "=[" .. str .. "]")
    io.write(tostring(s and ("[" .. s() .. "]")))
    io.write(tostring(m and "\t"..m or "") .. "\n")
    print()
    -- TODO assert that printed status and printed error are
    -- the same between parse52()/parseString52() vs load()
  end
  -- test line stuff
  local t2 = {
    {"test\nother", 5, 1},
    {"test\nother", 6, 2},
    {"\n", 1, 1},
    {"\n", 2, 2}, -- there is no char 2 but that's not the point
  }
  for i, temp in ipairs(t2) do
    local got, expect = getline(temp[1], temp[2]), temp[3]
    assert(got == expect, ("got %d, expected %d (for %d)"):format(got, expect, i))
  end
elseif _VERSION == "Lua 5.3" and not ... then
  -- test string parsing
  local t = {
    [=["\""]=],
    [=["\32"]=],
    [=["\256"]=],
    [=["\xnn"]=],
    '"\\\n"',
    [=["\x"]=],
    [=["\xn"]=],
    [=['\x']=],
    [=['\x0']=],
    [=['   \\z\ 
    \x']=],
    [=['\\z 
    ']=],
    [=['
    ']=],
    [=['\u{10FFFF}']=],
    [=['\u{20}']=],
    [=[' \z \z \z \
\
\x']=],
    [=['\u{1']=],
  }
  for _, str in ipairs(t) do
    local s, m = xpcall(parseString53, function(m) if m:sub(1,1) ~= "[" then print(debug.traceback()) end return m end, str)
    io.write(tostring(s and ("[" .. m .. "]") or "nil"))
    io.write(tostring(s and "" or ("\t" .. m)) .. "\n")
    s, m = load("return " .. str, "=[" .. str .. "]")
    io.write(tostring(s and ("[" .. s() .. "]")))
    io.write(tostring(m and "\t"..m or "") .. "\n")
    print()
    -- TODO assert that printed status and printed error are
    -- the same between parse53()/parseString53() vs load()
  end
  -- test line stuff
  local t2 = {
    {"test\nother", 5, 1},
    {"test\nother", 6, 2},
    {"\n", 1, 1},
    {"\n", 2, 2}, -- there is no char 2 but that's not the point
  }
  for _, temp in ipairs(t2) do
    local got, expect = getline(temp[1], temp[2]), temp[3]
    assert(got == expect, ("got %d, expected %d"):format(got, expect))
  end
elseif not ... then
  print("Tests require Lua 5.2")
end

return {
  parse52 = parseString52,
  parse53 = parseString53,
  findpairs = findpairs,
  getline = getline,
}

