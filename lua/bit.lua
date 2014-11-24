--[[---------------
LuaBit v0.4
-------------------
a bitwise operation lib for lua.
SoniEx2: very fast bitwise lib in pure Lua, compatible with Lua 5.1

http://luaforge.net/projects/bit/

How to use:
-------------------
 bit.bnot(n) -- bitwise not (~n)
 bit.band(m, n) -- bitwise and (m & n)
 bit.bor(m, n) -- bitwise or (m | n)
 bit.bxor(m, n) -- bitwise xor (m ^ n)
 bit.bxor2(m, n) -- bitwise xor (m ^ n), alternative version
 bit.brshift(n, bits) -- right shift (n >> bits)
 bit.blshift(n, bits) -- left shift (n << bits)
 bit.blogic_rshift(n, bits) -- logic right shift(zero fill >>>)
 
Please note that bit.brshift and bit.blshift only support number within
32 bits.

2 utility functions are provided too:
 bit.tobits(n) -- convert n into a bit table(which is a 1/0 sequence)
               -- high bits first
 bit.tonumb(bit_tbl) -- convert a bit table into a number 
-------------------
SoniEx2: TODO list:
 bit.bnot(n) -- TODO
 bit.band(m, n) -- TODO
 bit.bor(m, n) -- TODO
 bit.bxor(m, n) -- TODO
 bit.bxor2(m, n) -- ???
 bit.brshift(n, bits) -- DONE
 bit.blshift(n, bits) -- DONE
 bit.blogic_rshift(n, bits) -- DONE
 bit.tobits(n) -- ???
 bit.tonumb(bit_tbl) -- ???
-------------------

Under the MIT license.

copyright(c) 2006~2007 hanzhao (abrash_han@hotmail.com)
copyright(c) 2014 SoniEx2
--]]---------------

local bit

do

------------------------
-- bit lib implementions

-- SoniEx2: status = good
local function check_int(n)
 -- checking not float
 --if(n - math.floor(n) > 0) then
 -- SoniEx2: 2 to 10+ times faster (Rio Lua 5.1) see: http://codepad.org/MbzqzJ8D
 -- No difference in LuaJIT (but then you shouldn't be using this library anyway)
 -- Doesn't work in Lua 5.0
 if(n % 1 ~= 0) then
  error("trying to use bitwise operation on non-integer!")
 end
end

-- defined below
local bit_not

-- SoniEx2: status = ???
local function to_bits(n)
 check_int(n)
 if(n < 0) then
  -- negative
  return to_bits(bit_not(math.abs(n)) + 1)
 end
 -- to bits table
 local tbl = {}
 local cnt = 1
 while (n > 0) do
  --local last = math.mod(n,2)
  --if(last == 1) then
   --tbl[cnt] = 1
  --else
   --tbl[cnt] = 0
  --end
  -- SoniEx2
  local last = n % 2
  tbl[cnt] = last
  n = (n-last)/2
  cnt = cnt + 1
 end

 return tbl
end

-- SoniEx2: status = ???
local function tbl_to_number(tbl)
 local n = table.getn(tbl)

 local rslt = 0
 local power = 1
 for i = 1, n do
  rslt = rslt + tbl[i]*power
  power = power*2
 end
 
 return rslt
end

-- SoniEx2: status = ???
local function expand(tbl_m, tbl_n)
 local big = {}
 local small = {}
 if(table.getn(tbl_m) > table.getn(tbl_n)) then
  big = tbl_m
  small = tbl_n
 else
  big = tbl_n
  small = tbl_m
 end
 -- expand small
 for i = table.getn(small) + 1, table.getn(big) do
  small[i] = 0
 end

end

-- SoniEx2: status = TODO
local function bit_or(m, n)
 local tbl_m = to_bits(m)
 local tbl_n = to_bits(n)
 expand(tbl_m, tbl_n)

 local tbl = {}
 local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
 for i = 1, rslt do
  if(tbl_m[i]== 0 and tbl_n[i] == 0) then
   tbl[i] = 0
  else
   tbl[i] = 1
  end
 end
 
 return tbl_to_number(tbl)
end

-- SoniEx2: status = TODO
local function bit_and(m, n)
 local tbl_m = to_bits(m)
 local tbl_n = to_bits(n)
 expand(tbl_m, tbl_n) 

 local tbl = {}
 local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
 for i = 1, rslt do
  if(tbl_m[i]== 0 or tbl_n[i] == 0) then
   tbl[i] = 0
  else
   tbl[i] = 1
  end
 end

 return tbl_to_number(tbl)
end

-- SoniEx2: status = TODO
-- declared above
function bit_not(n)
 
 local tbl = to_bits(n)
 local size = math.max(table.getn(tbl), 32)
 for i = 1, size do
  if(tbl[i] == 1) then 
   tbl[i] = 0
  else
   tbl[i] = 1
  end
 end
 return tbl_to_number(tbl)
end

-- SoniEx2: status = TODO
local function bit_xor(m, n)
 local tbl_m = to_bits(m)
 local tbl_n = to_bits(n)
 expand(tbl_m, tbl_n) 

 local tbl = {}
 local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
 for i = 1, rslt do
  if(tbl_m[i] ~= tbl_n[i]) then
   tbl[i] = 1
  else
   tbl[i] = 0
  end
 end
 
 --table.foreach(tbl, print)

 return tbl_to_number(tbl)
end

-- SoniEx2: use lookup table for shifts
-- this can be from 1.2 (worst case) to MANY times faster than
-- the original method (for loops), and is 2-3 times faster than
-- 2^x (except for x == 1 or x == 2)
local bit_shift_lookup = {}
-- calculate at runtime so we don't use 32 lines for it
for i = 1, 31 do
  bit_shift_lookup[i] = 2^i
end

local high_bit_lookup = {
  [1] = 2147483648,
  [2] = 2147483648 + 2147483648 / 2}
for i = 1, 31 do
  local x = 0
  for j = 31, 32-i, -1 do
    x = x + 2^j
  end
  high_bit_lookup[i] = x
end

-- SoniEx2: status = good
local function bit_rshift(n, bits)
 check_int(n)
 
 local high_bit = false
 if(n < 0) then
  -- negative
  n = bit_not(math.abs(n)) + 1
  --high_bit = 2147483648 -- 0x80000000
  high_bit = true
 end

 --for i=1, bits do
  --n = n/2
  --n = bit_or(math.floor(n), high_bit)
 --end
 if bits <= 0 then
 elseif bits >= 32 then
  n = high_bit and 4294967295 or 0
 else
  n = (n % 2^32) / bit_shift_lookup[bits]
  n = math.floor(n) + (high_bit and high_bit_lookup[bits] or 0)
 end
 return math.floor(n)
end

-- SoniEx2: status = good
-- logic rightshift assures zero filling shift
local function bit_logic_rshift(n, bits)
 check_int(n)
 if(n < 0) then
  -- negative
  n = bit_not(math.abs(n)) + 1
 end
 if bits <= 0 then
 elseif bits >= 32 then
  n = 0
 else
  n = n / bit_shift_lookup[bits]
 end
 return math.floor(n)
end

-- SoniEx2: status = good
local function bit_lshift(n, bits)
 check_int(n)
 
 if(n < 0) then
  -- negative
  n = bit_not(math.abs(n)) + 1
 end

 --for i=1, bits do
  --n = n*2
 --end
 -- SoniEx2: Faster code
 if bits <= 0 then
 elseif bits >= 32 then
  n = 0
 else
  n = n * bit_shift_lookup[bits]
 end
 -- return bit_and(n, 4294967295) -- 0xFFFFFFFF
 -- SoniEx2: 2 orders of magnitude faster!
 return n % 4294967296 -- 0xFFFFFFFF + 1
end

-- SoniEx2: status = ???
local function bit_xor2(m, n)
 local rhs = bit_or(bit_not(m), bit_not(n))
 local lhs = bit_or(m, n)
 local rslt = bit_and(lhs, rhs)
 return rslt
end

--------------------
-- bit lib interface

bit = {
 -- bit operations
 bnot = bit_not,
 band = bit_and,
 bor  = bit_or,
 bxor = bit_xor,
 brshift = bit_rshift,
 blshift = bit_lshift,
 bxor2 = bit_xor2,
 blogic_rshift = bit_logic_rshift,

 -- utility func
 tobits = to_bits,
 tonumb = tbl_to_number,
}

end

--[[
for i = 1, 100 do
 for j = 1, 100 do
  if(bit.bxor(i, j) ~= bit.bxor2(i, j)) then
   error("bit.xor failed.")
  end
 end
end
--]]

return bit
