--[[
    Content Warning CTCP for HexChat

    The MIT License (MIT)

    Copyright (c) 2017 Soni L. <soniex2 at gmail dot com>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

--]]
local hexchat = hexchat
hexchat.register("CTCP-S CW", "2.1.1", "CTCP-S CW for HexChat.")

package.preload.rc4 = function(...)
--[[
	lrc4 - Native Lua/LuaJIT RC4 stream cipher library - https://github.com/CheyiLin/lrc4
	
	The MIT License (MIT)
	
	Copyright (c) 2015 Cheyi Lin <cheyi.lin@gmail.com>
	Copyright (c) 2017 Soni L. <soniex2 at gmail dot com>
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

  local require = require
  local setmetatable = setmetatable

  local string_char = string.char
  local table_concat = table.concat

  local is_luajit
  local bit_xor, bit_and

  local load = load

  if jit and jit.version_num > 20000 then
    is_luajit = true
    bit_xor = bit.bxor
    bit_and = bit.band
  elseif _VERSION == "Lua 5.2" then
    bit_xor = bit32.bxor
    bit_and = bit32.band
  elseif _VERSION == "Lua 5.3" then
    bit_xor = load "return function(a, b) return a ~ b end" ()
    bit_and = load "return function(a, b) return a & b end" ()
  else
    error("unsupported Lua version")
  end

  local new_ks, rc4_crypt

  local pattern = "@([a-zA-Z0-9_]+)(%b())(%b())"
  local function preprocessor(cmd, arg1, arg2) -- huge performance boost
    -- process args too
    arg1 = arg1:gsub(pattern, preprocessor)
    arg2 = arg2:gsub(pattern, preprocessor)
    if cmd == "bit_xor" then
      if _VERSION == "Lua 5.3" then
        return "(" .. arg1 .. " ~ " .. arg2 .. ")"
      else
        return "bit_xor(" .. arg1 .. "," .. arg2 .. ")"
      end
    elseif cmd == "bit_and" then
      if _VERSION == "Lua 5.3" then
        return "(" .. arg1 .. " & " .. arg2 .. ")"
      else
        if arg2 == "(255)" then
          return "(" .. arg1 .. " % 256)"
        else
          return "bit_and(" .. arg1 .. "," .. arg2 .. ")"
        end
      end
    end
    error("unreachable")
  end

  if is_luajit then
    -- LuaJIT ffi implementation
    local ffi = require("ffi")
    local ffi_string = ffi.string
    local ffi_copy = ffi.copy

    ffi.cdef [[
		typedef struct { uint8_t v; } idx_t;
	]]

    local st_ct = ffi.typeof("uint8_t[256]")
    local idx_ct = ffi.typeof("idx_t")	-- NOTE: boxed uint8_t for the overflow behavoir 
    local buf_ct = ffi.typeof("uint8_t[?]")

    new_ks =
    function (key)
      local st = st_ct()
      for i = 0, 255 do st[i] = i end

      local key_len = #key
      local buf = buf_ct(key_len)	-- NOTE: buf_ct(#key, key) will cause segfault and not compiled,
      ffi_copy(buf, key, key_len)	--       separating alloc & copy is safer and faster

      local j = idx_ct()
      for i = 0, 255 do
        j.v = j.v + st[i] + buf[i % key_len]
        st[i], st[j.v] = st[j.v], st[i]
      end

      return {x=idx_ct(), y=idx_ct(), st=st}
    end

    rc4_crypt =
    function (ks, input)
      local x, y, st = ks.x, ks.y, ks.st

      local input_len = #input
      local buf = buf_ct(input_len)
      ffi_copy(buf, input, input_len)

      for i = 0, (input_len - 1) do
        x.v = x.v + 1
        y.v = y.v + st[x.v]
        st[x.v], st[y.v] = st[y.v], st[x.v]
        buf[i] = bit_xor(buf[i], st[bit_and(st[x.v] + st[y.v], 255)])
      end

      return ffi_string(buf, input_len)
    end
  else
    -- plain Lua implementation
    new_ks =
    assert(load(([[
		local string_byte = string.byte
		local bit_xor, bit_and = ...
		return function (key)
			local st = {}
			for i = 0, 255 do st[i] = i end
			
			local len = #key
			local j = 0
			for i = 0, 255 do
				j = @bit_and(j + st[i] + string_byte(key, (i % len) + 1))(255)
				st[i], st[j] = st[j], st[i]
			end
			
			return {x=0, y=0, st=st}
		end
		]]):gsub(pattern, preprocessor)))(bit_xor, bit_and)

    rc4_crypt =
    assert(load(([[
		local string_char = string.char
		local string_byte = string.byte
		local table_concat = table.concat
		local bit_xor, bit_and = ...
		return function (ks, input)
			local x, y, st = ks.x, ks.y, ks.st
			
			local t = {}
			for i = 1, #input do
				x = @bit_and(x + 1)(255)
				y = @bit_and(y + st[x])(255)
				st[x], st[y] = st[y], st[x]
				t[i] = string_char(@bit_xor(string_byte(input, i))(st[@bit_and(st[x] + st[y])(255)]))
			end
			
			ks.x, ks.y = x, y
			return table_concat(t)
		end
		]]):gsub(pattern, preprocessor)))(bit_xor, bit_and)
  end

  local function new_rc4(m, key)
    local o = new_ks(key)
    return setmetatable(o, {__call=rc4_crypt, __metatable=false})
  end

-- self testing
  if (not ...) or (arg and ... == arg[1]) then
    local os_clock = os.clock
    local function printf(fmt, ...) io.write(string.format(fmt, ...), "\n") end

    local loop = tonumber(arg[1]) or 100000
    local key = "\x5a\x40\x18\xde\x47\xe9\x9a\xec"
    local t1

    t1 = os_clock()
    for i = 1, loop do
      local r = new_rc4(nil, key)
    end
    printf("%-16s %8.3f sec (%d times, #key %d)",
      "RC4 keygen test", os_clock() - t1, loop, #key)

    collectgarbage()

    local r1 = new_rc4(nil, key)
    local r2 = new_rc4(nil, key)
    local s = 
"bS1hjNeePwaj6dY293F7rzmcTFjZVS9O9vAq5l69onIiZTOwZ3LrtuiWLT0Jpr3lZ0XJ11Ajw6RoyLP6Xf66lbFu68edKJK8oyGJLu9xFTQRaFXrsMu9nX4Q5qufETjU0nsN6JZxGXQZfAAcgFyvlik2tJEyovhHsEINhtXnYuj7VpUEZl8ZXAVf2Aa5cbSYVcb1wY3D2ts2kHHXVqUhKpYQ60LKGbWOB1CKkSDFR8JfL9tBmpezS9MWCh1yTUXjfFxSbEq3KV7c8qtwxKGjINoDAMWDQLO0qBGC8IitKyc1zbBUbHBPTvx9TPiGpYObQeX5Ktu7ZtiRpak2o5h9AfEXHCd4tL1F2OsQfpMZghGWnRAez32JeWksXis6X1uJAZgA6mB5Fc7CErLJCiSJVl1TbG4Z7KhypNN0MOfeVV7RY5shwQtYixzA86LNa4w8It2XyjYe6qrcYX3Eq3cKEFFfBPJXZnqwoO3W6MJ52KUrTWcOtqnnfOtWhm9FsLZM"

    t1 = os_clock()
    for i = 1, loop do
      local s1 = r1(s)
      local s2 = r2(s1)
      assert(s == s2)
    end
    printf("%-16s %8.3f sec (%d times, #key %d, #input %d)",
      "RC4 crypt test", os_clock() - t1, loop, #key, #s)
  end

----
-- @module rc4
-- 
-- @usage local rc4 = require("rc4")
--        local key = "my_secret"
--        local rc4_enc = rc4(key)
--        local rc4_dec = rc4(key)
--        
--        local plain = "plain_text_string" 
--        local encrypted = rc4_enc(plain)
--        local decrypted = rc4_dec(encrypted)
--        assert(plain == decrypted)

  return setmetatable({}, {__call=new_rc4, __metatable=false})
end

package.preload.arc4random = function(...)
--[[
	arc4random - Pure Lua/LuaJIT arc4random pseudo-random number generator
	Part of lrc4 - Pure Lua/LuaJIT RC4 stream cipher library - https://github.com/CheyiLin/lrc4

	The MIT License (MIT)

	Copyright (c) 2017 Soni L. <soniex2 at gmail dot com>

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

  local rc4 = require "rc4"
  local string_byte = string.byte

  local next_byte = function(st)
    return string_byte(st('\0'))
  end
  local make_rng = function(m, seed)
    local st = rc4(seed)
    return function() return next_byte(st) end
  end

  return setmetatable({}, {__call=make_rng, __metatable=false})
end

package.preload.stringliteral = function(...)
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
end

local arc4random = require "arc4random"
local stringliteral = require "stringliteral"

local function arc4r256u(rng, i)
  local min, r = 256 % i
  repeat
    r = rng()
  until r >= min
  return r % i
end

local function shuffle(t, key)
  local rng = arc4random(key)
  for i = #t, 2, -1 do
    local j = 1 + arc4r256u(rng, i)
    t[i], t[j] = t[j], t[i]
  end
end

local function deshuffle(t, from, len, key)
  local from = from - 1
  local t2 = {}
  for i = 1, len do
    t2[i]=i
  end
  shuffle(t2, key)
  local t3 = {}
  for i, v in ipairs(t2) do
    t3[v] = t[from + i]
  end
  return t3
end

local shuffle = function(t, from, len, key)
  local from = from - 1
  local t2 = {}
  for i = 1, len do
    t2[i]=i
  end
  shuffle(t2, key)
  local t3 = {}
  for i, v in ipairs(t2) do
    t3[i] = t[from + v]
  end
  return t3
end

local utf8pattern = (_VERSION == "Lua 5.1" and "[%z" or "[\0") .. "\1-\x7F\xC2-\xF4][\x80-\xBF]*"

local function strtot(str)
  local t = {}
  local ac = 0
  str:gsub(utf8pattern, function(c) ac = ac + 1 t[ac] = c end)
  return t, ac
end

local function cmd_cw(word, word_eol)
  (function()
      if not word_eol[2]:match("^[^ ]+ .+$", 2) then
        hexchat.print("Usage: /cw <reason> <content>")
        return
      end
      local cw, msg = word_eol[2]:match("^([^ ]+) (.+)$")
      if cw:sub(1,1) == "'" or cw:sub(1,1) == '"' then
        local m, pos
        repeat
          m, pos = string.match(word_eol[2], "(\\*)"..cw:sub(1,1).."()", pos or 2)
        until m == nil or #m % 2 == 0
        if m == nil then
          hexchat.print("Unfinished string")
          return
        end
        local ok
        ok, cw = pcall(stringliteral.parse53, word_eol[2]:sub(1, pos-1))
        if not ok then
          hexchat.print(cw)
          return
        end
        if word_eol[2]:sub(pos,pos) ~= " " then
          hexchat.print("Syntax error at " .. pos)
          return
        end
        msg = word_eol[2]:sub((string.find(word_eol[2], "[^ ]", pos+1)))
      end
      if msg:sub(1,1) == "'" or msg:sub(1,1) == '"' then
        ok, msg = pcall(stringliteral.parse53, msg)
        if not ok then
          hexchat.print(msg)
          return
        end
      end
      local msgt = strtot(msg)
      local n = math.ceil((#msgt)/256)
      local s = math.ceil((#msgt)/n)
      local o = {}
      for i=1,#msgt,s do
        local shuffledt = shuffle(msgt, i, math.min(s+i, #msgt+1)-i, "Content warnings shall use a seeded arc4random")
        table.insert(o, "\1CW0 " .. table.concat(shuffledt) .. "\1")
      end
      hexchat.command("say " .. cw .. table.concat(o))
    end)()
  return hexchat.EAT_ALL
end

local function cmd_decw(word, word_eol)
  if word[2] then
    local data = strtot(word_eol[2])
    local deshuffledt = deshuffle(data, 1, #data, "Content warnings shall use a seeded arc4random")
    hexchat.print(table.concat(deshuffledt))
  else
    hexchat.print("Usage: /decw <data>")
  end
  return hexchat.EAT_ALL
end

local function startswith(str1, str2)
  return str1:sub(1, #str2) == str2
end

local function parsecw(msg)
  local hidden = {}
  local lastfinish = -1
  msg = msg:gsub("()(\1([^\1]*)\1)()", function(start, ctcp, contents, finish)
      if startswith(contents, "CW0 ") then
        local cw = contents:sub(5)
        local data = strtot(cw)
        if #data > 256 then return ctcp end -- rare enough that this isn't a performance issue
        local deshuffledt = deshuffle(data, 1, #data, "Content warnings shall use a seeded arc4random")
        if lastfinish == start then
          hidden[#hidden] = hidden[#hidden] .. table.concat(deshuffledt)
          return ""
        else
          hidden[#hidden + 1] = table.concat(deshuffledt)
          return " [Hidden Text " .. #hidden .. "] "
        end
      end
      return ctcp
    end)
  return msg, hidden
end

local tunpack = unpack or table.unpack

local skip = false
local function mkparse(event, pos)
  return function(word, attributes)
    if skip then return end
    local old_msg = word[pos]
    local hidden
    word[pos], hidden = parsecw(word[pos])
    if word[pos] ~= old_msg then
      skip = true
      hexchat.emit_print_attrs(attributes, event, tunpack(word))
      for i, v in ipairs(hidden) do
        hexchat.print("\00326*\tHidden Text " .. i .. "\3 > \8"..v.."\8 < (Copy and paste to expand)")
      end
      skip = false
      return hexchat.EAT_ALL
    end
  end
end

local function hookparse(event, pos)
  return hexchat.hook_print_attrs(event, mkparse(event, pos))
end

hexchat.hook_command("cw", cmd_cw)
hexchat.hook_command("decw", cmd_decw)

do
  (function(f,...)return f(f,...) end)(function(f, a, b, ...)
      if a then 
        hookparse(a, b)
        return f(f, ...)
      end
    end,
    "Channel Message", 2,
    "Channel Msg Hilight", 2,
    "Channel Notice", 3,
    "Private Message", 2,
    "Private Message to Dialog", 2,
    "Notice", 2,
    "Your Message", 2,
    "Notice Send", 2,
    "Message Send", 2,
    nil)
end

print("cw.lua loaded")
