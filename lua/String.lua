local squote = string.byte("'")
local dquote = string.byte('"')

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

-- Parse a string like it's a Lua 5.2 string.
local function parseString52(s)
  -- "validate" string
  local startChar = string.byte(s,1,1)
  assert(startChar==squote or startChar==dquote)
  assert(string.byte(s, -1, -1) == startChar)

  -- remove quotes
  local str = string.sub(s, 2, -2)

  -- TODO check for unescaped quotes

  -- replace "normal" escapes with a padded escape
  str = string.gsub(str, "\\([^zx0-9])", "\\v*%1")

  -- pad 1-digit numerical escapes
  str = string.gsub(str, "\\([0-9])[^0-9]", "\\00%1")

  -- pad 2-digit numerical escapes
  str = string.gsub(str, "\\([0-9][0-9])[^0-9]", "\\0%1")

  -- strip \z (and spaces)
  str = string.gsub(str, "\\z%s+", "")

  -- parse results
  str = string.gsub(str, "\\(([vx0-9])(.(.)))",
    function(a,b,c,d)
      if b == "v" then
        return escapeSequences[d] or error("invalid escape sequence near '\\" .. d .. "'")
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

return {
  parse52 = parseString52,
}