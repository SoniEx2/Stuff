local squote = "'"
local dquote = '"'

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
  ['"'] = chartopad('\"'),
  ["'"] = chartopad('\''),
['\\'] = chartopad('\\')
}

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

setmetatable(pads, {
    __index = function(t,k) error("invalid escape sequence near '\\" .. k .. "'", 3) end
  })

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

-- Parse a string like it's a Lua 5.2 string.
local function parseString52(s)
  -- "validate" string
  local startChar = string.sub(s,1,1)
  assert(startChar==squote or startChar==dquote, "not a string")
  assert(string.sub(s, -1, -1) == startChar, "unfinished string")

  -- remove quotes
  local str = string.sub(s, 2, -2)

  -- replace "normal" escapes with a padded escape
  str = string.gsub(str, "\\(.)", pads)

  -- check for non-escaped startChar
  assert(not string.find(str, startChar), "unfinished string")

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
      local temp1 = ("0"):rep(3 - #x)
      return "\\" .. temp1 .. x .. b .. c
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
  for x,y in ipairs(t) do
    nt[x] = string.gsub(y, "\\(([x0-9])((.).))",
      function(a,b,c,d)
        if b ~= "x" then
          local n = tonumber(a)
          assert(n < 256, "decimal escape too large near '\\" .. a .. "'")
          return string.char(n)
        else
          local n = tonumber(c, 16)
          assert(n, "hexadecimal digit expected near '\\x" .. c .. "'")
          return string.char(n)
        end
      end)
    if x > 1 then
      -- handle \z
      nt[x] = string.gsub(nt[x], "^[%s]*", "")
    end
  end
  -- merge
  return table.concat(nt, "")
end

-- "tests"
-- TODO add more
-- also add automatic checks
if _VERSION == "Lua 5.2" and not ... then
  local t = {
    [=["\""]=],
    [=["""]=],
    [=["v""]=],
    [=[""/"]=],
    [=["\v"/"]=],
    [=["\m"]=],
    [=["\32"]=],
  }
  for _, str in ipairs(t) do
    local s, m = pcall(parseString52, str)
    io.write(tostring(s and m or "nil"))
    io.write(tostring(s and "" or ("\t" .. m)) .. "\n")
    s, m = load("return " .. str, "@/home/soniex2/git/github/Stuff/lua/String.lua:")
    io.write(tostring(s and s()))
    io.write(tostring(m and "\t"..m or "") .. "\n")
  end
elseif not ... then
  print("Tests require Lua 5.2")
end

return {
  parse52 = parseString52,
  findpairs = findpairs,
}