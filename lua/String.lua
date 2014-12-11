local squote = "'"
local dquote = '"'

-- escape "sequences"
local escapeSequences = {
  a = '\a',
  b = '\b',
  f = '\f',
  r = '\r',
  n = '\n',
  t = '\t',
  v = '\v',
  ['"'] = '"',
  ["'"] = "'",
  ['\\'] = '\\'
}

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
  ['9'] = '\\9'
}

setmetatable(pads, {
    __index = function(t,k)
      return "\\v" .. k .. "/"
    end
  })

-- Parse a string like it's a Lua 5.2 string.
local function parseString52(s)
  -- "validate" string
  local startChar = string.sub(s,1,1)
  assert(startChar==squote or startChar==dquote)
  assert(string.sub(s, -1, -1) == startChar)

  -- remove quotes
  local str = string.sub(s, 2, -2)

  -- TODO check for unescaped quotes

  -- replace "normal" escapes with a padded escape
  str = string.gsub(str, "\\(.)", function(c)
      -- swap startChar with some invalid escape
      if c == startChar then
        c = "m"
      -- swap the invalid escape with startChar
      elseif c == "m" then
        c = startChar
      end
      return pads[c]
    end)

  -- check for a padded escape for startChar - remember this is actually our invalid escape
  assert(not string.find(str, "\\v" .. startChar .. "/"), "invalid escape sequence near '\\m'")
  
  -- then check for non-escaped startChar
  assert(not string.find(str, startChar), "unfinished string")

  -- pad 1-digit numerical escapes
  str = string.gsub(str, "\\([0-9])[^0-9]", "\\00%1")

  -- pad 2-digit numerical escapes
  str = string.gsub(str, "\\([0-9][0-9])[^0-9]", "\\0%1")

  -- strip \z (and spaces)
  str = string.gsub(str, "\\z[%s\n\r]+", "")

  -- parse results
  str = string.gsub(str, "\\(([vx0-9])((.).))",
    function(a,b,c,d)
      if b == "v" then
        return escapeSequences[d] or (d == "m" and startChar or assert(false, "invalid escape sequence near '\\" .. d .. "'"))
      elseif b == "x" then
        local n = tonumber(c, 16)
        assert(n, "hexadecimal digit expected near '\\x" .. c .. "'")
        return string.char(n)
      else
        local n = tonumber(a)
        assert(n < 256, "decimal escape too large near '\\" .. a .. "'")
        return string.char(n)
      end
    end)
  return str
end

-- "tests"
-- TODO add more
-- also add automatic checks
if _VERSION == "Lua 5.2" and not ... then
  local t = {
    [["\""]],
    [["""]],
    [["v""]],
    [[""/"]],
    [["\v"/"]],
    [["\m"]]
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
}