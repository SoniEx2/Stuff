--[[
    (Standalone) Content Warning CTCP Encoding.
    Useful if your IRC client doesn't support Lua but supports calling external programs and reading their stdout.

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

  local load = loadstring or load

  if jit and jit.version_num > 20000 then
    is_luajit = true
    bit_xor = bit.bxor
    bit_and = bit.band
  elseif _VERSION == "Lua 5.1" then
    local string_format = string.format
    local tonumber = tonumber
    bit_xor = function(a, b)
      local a = string_format("%03o", a)
      local b = string_format("%03o", b)
      return tonumber(a:gsub("()(.)", function(i, v)
            local v2 = b:sub(i,i)
            local x = 1 + tonumber(v, 8) * 8 + tonumber(v2, 8)
            local r = ('0123456710325476230167453210765445670123547610326745230176543210'):sub(x, x)
            return r ~= "" and r or error("unreachable")
          end), 8)
    end
    bit_and = error
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
          return "(" .. arg1 .. " % (256))"
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

local arc4random = require "arc4random"

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

local ishuffle = shuffle

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

local utf8pattern = (_VERSION == "Lua 5.1" and "[%z" or "[\0") .. "\1-\127\194-\244][\128-\191]*"

local function strtot(str)
  local t = {}
  local ac = 0
  str:gsub(utf8pattern, function(c) ac = ac + 1 t[ac] = c end)
  return t, ac
end

local function encode(msg)
  local msgt = strtot(msg)
  local n = math.ceil((#msgt)/256)
  local s = math.ceil((#msgt)/n)
  local o = {}
  for i=1,#msgt,s do
    local shuffledt = shuffle(msgt, i, math.min(s+i, #msgt+1)-i, "Content warnings shall use a seeded arc4random")
    table.insert(o, table.concat(shuffledt))
  end
  return o
end

local function decode(s)
  local t = strtot(s)
  return table.concat(deshuffle(t, 1, #t, "Content warnings shall use a seeded arc4random"), '')
end

if arg and arg[1] then
  if arg[1] == '-d' then
    print(decode(arg[2]))
  elseif arg[1] == '-e' then
    for _, v in ipairs(encode(arg[2])) do
      print(v)
    end
  else
    print("Usage: -e <to encode> or -d <to decode>")
  end
  return
end

print('Type "encode" or "decode" to select a function')
local f = io.read()
if f:sub(1,1) == "e" then
  print("Please input the string to encode")
  local msg = io.read()
  print("Encoded:")
  for _, v in ipairs(encode(msg)) do
    print(v)
  end
elseif f:sub(1,1) == "d" then
  print("Please input the string to decode")
  local s = io.read()
  print("Decoded:")
  print(decode(s))
end

