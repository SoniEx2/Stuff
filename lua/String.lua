-- Faster? String.lua

local error = error
local tonumber = tonumber
local sfind = string.find
local ssub = string.sub
local schar = string.char
local sbyte = string.byte
local mfloor = math.floor

local simpleEscapes = {}
for i = 1, 255 do
  simpleEscapes[i] = false
end
for k,v in pairs({
    a = '\a',
    b = '\b',
    f = '\f',
    r = '\r',
    n = '\n',
    t = '\t',
    v = '\v',
    ['"'] = '"',
    ["'"] = "'",
    ['\\'] = '\\',
    }) do
  simpleEscapes[sbyte(k)] = v
end

local function parse52(s)
  local startChar = ssub(s,1,1)
  if startChar~="'" and startChar~='"' then
    error("not a string", 0)
  end
  local c = 0
  local ln = 1
  local t = {}
  local nj = 1
  local eos = #s
  local pat = "^([^\\" .. startChar .. "\r\n]*)([\\" .. startChar .. "\r\n])"
  local mkerr = function(emsg, ...)
    error(string.format('[%s]:%d: ' .. emsg, s, ln, ...), 0)
  end
  local lnj
  repeat
    lnj = nj
    local i, j, part, k = sfind(s, pat, nj + 1, false)
    if i then
      c = c + 1
      t[c] = part
      if k == "\\" then
        nj = j + 1
        local v = ssub(s, nj, nj)
        local simple = simpleEscapes[sbyte(v)]
        if simple then
          c = c + 1
          t[c] = simple
        elseif v == "\r" or v == "\n" then
          ln = ln + 1
          local v1 = ssub(s, nj + 1, nj + 1)
          if (v1 == "\r" or v1 == "\n") and v ~= v1 then
            nj = nj + 1
          end
          c = c + 1
          t[c] = '\n'
        elseif v == "x" then
          v = ssub(s, nj, nj+2)
          if tonumber(ssub(v, 2), 16) then
            nj = nj + 2
            c = c + 1
            t[c] = schar(tonumber(ssub(v, 2), 16))
          else
            mkerr("hexadecimal digit expected near '\\" .. v:match('x[0-9a-f]*.') .. "'")
          end
        elseif v == "z" then
          local eaten, np = s:match("^([\t\n\v\f\r ]*)()", nj+1)
          local p=np
          nj = p-1
          local skip = false
          local mode = 0
          local prev
          for at, crlf in eaten:gmatch('()([\r\n])') do
            local last = ssub(eaten, at-1, at-1)
            if skip and prev == last and last ~= crlf then
              skip = false
            else
              skip = true
              ln = ln + 1
            end
            prev = crlf
          end
        elseif tonumber(v, 10) then
          if tonumber(ssub(s, nj + 1, nj + 1)) then
            if tonumber(ssub(s, nj + 2, nj + 2)) then
              -- \000
              local b = tonumber(ssub(s, nj, nj+2), 10)
              if b > 255 then
                mkerr("decimal escape too large near '\\%s'", ssub(s, nj, nj+2))
              else
                c = c + 1
                t[c] = schar(b)
                nj = nj + 2
              end
            else
              -- \00
              c = c + 1
              t[c] = schar(tonumber(ssub(s, nj, nj+1), 10))
              nj = nj + 1
            end
          else
            -- \0
            c = c + 1
            t[c] = schar(tonumber(v, 10))
          end
        else
          mkerr("invalid escape sequence near '\\%s'", v)
        end
      elseif k == startChar then
        if eos-1 > j then
          mkerr("<eof> expected")
        end
        nj = nil
      elseif k == '\n' or k == '\r' then
        mkerr("unfinished string near '%s'", startChar .. table.concat(t))
        nj = nil
      end
    else
      nj = nil
    end
  until not nj
  if ssub(s, -1, -1) ~= startChar then
    mkerr("unfinished string near <eof>")
  end
  return table.concat(t)
end

local function parse53(s)
  local startChar = ssub(s,1,1)
  if startChar~="'" and startChar~='"' then
    error("not a string", 0)
  end
  local c = 0
  local ln = 1
  local t = {}
  local nj = 1
  local eos = #s
  local pat = "^([^\\" .. startChar .. "\r\n]*)([\\" .. startChar .. "\r\n])"
  local mkerr = function(emsg, ...)
    error(string.format('[%s]:%d: ' .. emsg, s, ln, ...), 0)
  end
  local lnj
  repeat
    lnj = nj
    local i, j, part, k = sfind(s, pat, nj + 1, false)
    if i then
      c = c + 1
      t[c] = part
      if k == "\\" then
        nj = j + 1
        local v = ssub(s, nj, nj)
        local simple = simpleEscapes[sbyte(v)]
        if simple then
          c = c + 1
          t[c] = simple
        elseif v == "\r" or v == "\n" then
          ln = ln + 1
          local v1 = ssub(s, nj + 1, nj + 1)
          if (v1 == "\r" or v1 == "\n") and v ~= v1 then
            nj = nj + 1
          end
          c = c + 1
          t[c] = '\n'
        elseif v == "x" then
          v = ssub(s, nj, nj+2)
          if tonumber(ssub(v, 2), 16) then
            nj = nj + 2
            c = c + 1
            t[c] = schar(tonumber(ssub(v, 2), 16))
          else
            mkerr("hexadecimal digit expected near '%s%s\\%s'", startChar, table.concat(t), v:match('x[0-9a-f]*.'))
          end
        elseif v == "z" then
          local eaten, np = s:match("^([\t\n\v\f\r ]*)()", nj+1)
          local p=np
          nj = p-1
          local skip = false
          local mode = 0
          local prev
          for at, crlf in eaten:gmatch('()([\r\n])') do
            local last = ssub(eaten, at-1, at-1)
            if skip and prev == last and last ~= crlf then
              skip = false
            else
              skip = true
              ln = ln + 1
            end
            prev = crlf
          end
        elseif v == "u" then
          if ssub(s, nj + 1, nj + 1) == '{' then
            local uc = s:match("^[0-9a-fA-F]+", nj + 2)
            if uc then
              if ssub(s, nj + 2 + #uc, nj + 2 + #uc) == '}' then
                local uv = tonumber(uc, 16)
                if #uc > 6 or uv > 1114111 then
                  mkerr("UTF-8 value too large near '%s%s\\%s'", startChar, table.concat(t), ssub(s, nj, nj + 1 + math.min(#uc, 6)))
                else
                  nj = nj + 2 + #uc
                  if uv < 128 then
                    c = c + 1
                    t[c] = schar(uv)
                  elseif uv < 2048 then
                    c = c + 1
                    t[c] = schar(192 + mfloor(uv/64), 128 + uv%64)
                  elseif uv < 65536 then
                    c = c + 1
                    t[c] = schar(224 + mfloor(uv/64/64), 128 + mfloor(uv/64)%64, 128 + uv%64)
                  else
                    c = c + 1
                    t[c] = schar(240 + mfloor(uv/64/64/64), 128 + mfloor(uv/64/64)%64, 128 + mfloor(uv/64)%64, 128 + uv%64)
                  end
                end
              else
                if #uc > 6 or tonumber(uc, 16) > 1114111 then
                  mkerr("UTF-8 value too large near '%s%s\\%s'", startChar, table.concat(t), ssub(s, nj, nj + 1 + math.min(#uc, 6)))
                end
                mkerr("missing '}' near '%s%s\\%s'", startChar, table.concat(t), ssub(s, nj, nj + 2 + #uc))
              end
            else
              mkerr("hexadecimal digit expected near '%s%s\\%s'", startChar, table.concat(t), ssub(s, nj, nj + 2))
            end
          else
            mkerr("missing '{' near '%s%s\\%s'", startChar, table.concat(t), ssub(s, nj, nj + 1))
          end
        elseif tonumber(v, 10) then
          if tonumber(ssub(s, nj + 1, nj + 1)) then
            if tonumber(ssub(s, nj + 2, nj + 2)) then
              -- \000
              local b = tonumber(ssub(s, nj, nj+2), 10)
              if b > 255 then
                mkerr("decimal escape too large near '%s%s\\%s'", startChar, table.concat(t), ssub(s, nj, nj+3))
              else
                c = c + 1
                t[c] = schar(b)
                nj = nj + 2
              end
            else
              -- \00
              c = c + 1
              t[c] = schar(tonumber(ssub(s, nj, nj+1), 10))
              nj = nj + 1
            end
          else
            -- \0
            c = c + 1
            t[c] = schar(tonumber(v, 10))
          end
        else
          mkerr("invalid escape sequence near '%s%s\\%s'", startChar, table.concat(t), v)
        end
      elseif k == startChar then
        if eos-1 > j then
          mkerr("<eof> expected")
        end
        nj = nil
      elseif k == '\n' or k == '\r' then
        mkerr("unfinished string near '%s'", startChar .. table.concat(t))
        nj = nil
      end
    else
      nj = nil
    end
  until not nj
  if ssub(s, -1, -1) ~= startChar then
    mkerr("unfinished string near <eof>")
  end
  return table.concat(t)
end

-- "tests"
-- TODO add more
-- also add automatic checks
if not ... then
  local mktests52 = function(...)
    return
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
    [=['\z
    ']=],
    [=['\z
    ]=],
    [=['hello\i']=],
    [=['"']=],
    [=["'"]=],
    [=[' \z \z \z \
\
\x']=],
    [=['\z\n']=],
    '"\\z\n\r\n\r\r\n\n\n',
    '"\\z \n\r \n\r \r\n \n \n',
    '"\\\r"',
    '"\\\n"',
    '"\\\r\n"',
    '"\\\n\r"',
    ...
  end

  local mktests53 = function(...)
    return
    [=['\u']=],
    [=['\u{']=],
    [=['\u{}']=],
    [=['\u{1']=],
    [=['\u{99999999999999999999999999999999}']=],
    [=['\u{99999999999999999999999999999999']=],
    [=['\u{110000}']=],
    [=['\u{110000']=],
    [=['\u{20}']=],
    [=['\u{10FFFF}']=],
    [=['\u{24}']=],
    [=['\u{A2}']=],
    [=['\u{20AC}']=],
    [=['\u{10438}']=],
    [=['\u{DF00}']=],
    ...
  end


  if _VERSION == "Lua 5.2" then
    -- test string parsing
    local t = {
      mktests52()
    }
    for _, str in ipairs(t) do
      local s, m = xpcall(function() return parse52(str) end, function(m) if m:sub(1,1) ~= "[" then print(debug.traceback()) end return m end)
      io.write(tostring(s and ("[" .. m .. "]") or "nil"))
      io.write(tostring(s and "" or ("\t" .. m)) .. "\n")
      local s2, m2 = load("return " .. str, "=[" .. str .. "]")
      io.write(tostring(s2 and ("[" .. s2() .. "]") or "nil"))
      io.write(tostring(m2 and "\t"..m2 or "") .. "\n")
      if s and s2 then
        assert(m == s2())
      elseif not (s or s2) then
        assert(m == m2)
      else
        assert(false)
      end
      print()
    end

    if os.getenv("BENCHMARK") == "NewString.lua-5.2" then
      local assert = assert
      local s = '"\\z \n\r \n\r \r\n \n \nHELLO\\44\\x20\\"\\"\\\\"'
      local s2 = 'HELLO\44\32""\\'
      for i = 1, 100000 do
        assert(parse52(s) == s2)
      end
    elseif os.getenv("BENCHMARK") == "load-5.2" then
      local load = load
      local assert = assert
      local s = 'return "\\z \n\r \n\r \r\n \n \nHELLO\\44\\x20\\"\\"\\\\"'
      local s2 = 'HELLO\44\32""\\'
      for i = 1, 100000 do
        assert(load(s)() == s2)
      end
    end
  elseif _VERSION == "Lua 5.3" then
    -- test string parsing
    local t = {
      mktests52(mktests53())
    }
    for _, str in ipairs(t) do
      local s, m = xpcall(parse53, function(m) if m:sub(1,1) ~= "[" then print(debug.traceback()) end return m end, str)
      io.write(tostring(s and ("[" .. m .. "]") or "nil"))
      io.write(tostring(s and "" or ("\t" .. m)) .. "\n")
      local s2, m2 = load("return " .. str, "=[" .. str .. "]")
      io.write(tostring(s2 and ("[" .. s2() .. "]")))
      io.write(tostring(m2 and "\t"..m2 or "") .. "\n")
      if s and s2 then
        assert(m == s2())
      elseif not (s or s2) then
        assert(m == m2)
      else
        assert(false)
      end
      print()
    end

    if os.getenv("BENCHMARK") == "NewString.lua-5.3" then
      local assert = assert
      local s = '"\\z \n\r \n\r \r\n \n \nHELLO\\44\\x20\\u{20}\\"\\"\\\\"'
      local s2 = 'HELLO\44\32\32""\\'
      for i = 1, 100000 do
        assert(parse53(s) == s2)
      end
    elseif os.getenv("BENCHMARK") == "load-5.3" then
      local load = load
      local assert = assert
      local s = 'return "\\z \n\r \n\r \r\n \n \nHELLO\\44\\x20\\u{20}\\"\\"\\\\"'
      local s2 = 'HELLO\44\32\32""\\'
      for i = 1, 100000 do
        assert(load(s)() == s2)
      end
    end
  else
    print("Test requirements:")
    print("Test Target | Notes")
    print("parse52     | _VERSION == 'Lua 5.2'")
    print("parse53     | _VERSION == 'Lua 5.3'")
  end
end

return {
  parse52 = parse52,
  parse53 = parse53,
}
