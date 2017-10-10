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
