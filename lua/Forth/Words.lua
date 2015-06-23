-- Converts an integer to a boolean
local function itob(i)
  return i ~= 0
end
-- Converts a boolean to an integer
local function btoi(b)
  return b and -1 or 0
end

local function uf(i, ...) -- underflow check
  if select("#", ...) < i then error("stack underflow") end
end

-- 2-input 1-output operator
local function op2i1o(f)
  return function(word, i, ...)
    uf(2, ...)
    return word, i, f(select(2, ...),  (...)), select(3, ...)
  end
end

local bit = select(2, pcall(require, "bit")) or {
  tobit = function(i) -- half-assed bit.tobit
    i = math.fmod(i, 2^32) --> math.fmod(-, +) = -
    if i < 0 then
      i = i + 2^32
    end
    i = math.floor(i)
    i = i % 2^32 -- low 32 bits
    local ioff = i % 2^31 -- low 31 bits (offset)
    return ioff - i + ioff
  end,
  bor = function(...)
    local n = select('#', ...)
    local args = {...}
    local out = {}
    local i = 0
    local j = 1
    local k = 0
    while true do
      i = i + 1
      local v = args[i]
      v = tobit(v)
      local d = math.floor(v / 2)
      out[j] = math.max(out[j] or 0, (v - d * 2))
      args[i] = d
      if d == 0 then k = k + 1 end
      i = i % n
      if i == 0 then
        j = j + 1
        if k == n then break end
        k = 0
      end
    end
    local v = 0
    for i=#out, 1, -1 do
      v = v * 2 + out[i]
    end
    return v
  end
}
local vm = require"VM"

local function signed(i)
  return bit.tobit(i)
end
local function unsigned(i)
  i = bit.tobit(i)
  if i < 0 then
    return i + 2^32
  else
    return i
  end
end

local envdata = {
  ["STACK-CELLS"]       = nil, -- unknown
  ["MAX-N"]             = {bit.bor(2^31-1, 0)},
  ["MAX-U"]             = {2^32-1},
  ["MAX-D"]             = {2^31-1, 2^32-1},
  ["MAX-UD"]            = {2^32-1, 2^32-1},
  ["ADDRESS-UNIT-BITS"] = {8}, --?
}

-- Words
local cw = {
  -- simple stack operations
  ["DUP"] = function(word, i, ...)
    uf(1, ...)
    return word, i, ..., ...
  end,
  ["DROP"] = function(word, i, ...)
    uf(1, ...)
    return word, i, select(2, ...)
  end,
  ["SWAP"] = function(word, i, ...)
    uf(2, ...)
    return word, i, select(2, ...),  ..., select(3, ...)
  end,
  -- math
  ["+"]   = op2i1o(function(a,b) return            signed(a + b ,0) end),
  ["-"]   = op2i1o(function(a,b) return            signed(a - b ,0) end),
  ["*"]   = op2i1o(function(a,b) return            signed(a * b ,0) end),
  ["/"]   = op2i1o(function(a,b) return signed(math.floor(a / b),0) end),
  ["MOD"] = op2i1o(function(a,b) return            signed(a % b ,0) end),
  -- compare
  ["="]   = op2i1o(function(a,b) return btoi(a ==b) end),
  ["<>"]  = op2i1o(function(a,b) return btoi(a ~=b) end),
  ["<"]   = op2i1o(function(a,b) return btoi(a < b) end),
  [">"]   = op2i1o(function(a,b) return btoi(a > b) end),
  ["<="]  = op2i1o(function(a,b) return btoi(a <=b) end),
  [">="]  = op2i1o(function(a,b) return btoi(a >=b) end),
  -- logic/branching
  ["BRANCH"] = function(word, i, ...)
    return word, i + 1 + word[i], ...
  end,
  ["?BRANCH"] = function(word, i, ...)
    uf(1, ...)
    return word, itob(...) and i + 1 or i + 1 + word[i], select(2, ...)
  end,
  -- I/O
  ["."] = function(word, i, ...)
    uf(1, ...)
    io.write(tostring((...))," ")
    return word, i, select(2, ...)
  end,
  ["KEY"] = function(word, i, ...)
    return word, i, io.read(1):byte(), ...
  end,
  ["EMIT"] = function(word, i, ...)
    uf(1, ...)
    io.write(string.char((...)))
    return word, i, select(2, ...)
  end,
  ["ENVIRONMENT?"] = function(word, i, ...)
    uf(2, ...)
    local len, addr = ...
    local data = envdata[data:sub(addr, addr+len)]
    if #data == 1 then
      return word, i, btoi(true), data[1], select(3, ...)
    elseif #data == 2 then
      return word, i, btoi(true), data[1], data[2], select(3, ...)
    end
    return word, i, btoi(false), select(3, ...)
  end,
}
-- return stack stuff (warning: mess)
do
  local function swap(a, b, ...) return b, a, ... end

  -- push return stack
  local function tor(word, i, ...)
    uf(1, ...)
    local v1 = ...
    return word, swap(v1, vm.vm(word, i, select(2, ...)))
  end
  cw[">R"] = tor
  -- pop return stack
  local function rfrom(word, i, ...)
    return word, 0, i, ...
  end
  cw["R>"] = rfrom
  -- fetch return stack (PAINFUL)
  local sentinel = {}
  local function rfetch(word, i, ...)
    if swap(...) == sentinel then
      return tor(word, i, ..., select(2, swap(...)))
    end
    return word, 0, i - 1, sentinel, ...
  end
  cw["R@"] = rfetch

  -- 2 variants

  -- push return stack
  local function twotor(word, i, ...)
    uf(2, ...)
    local v2, v1 = ...
    return word, swap(v1,
      vm.vm(word, 
        swap(v2,
          vm.vm(word, i, select(3, ...))
        )
      )
    )
  end
  cw["2>R"] = twotor

  -- pop return stack
  local tworfromsentinel = {}
  local tworfromswapsentinel = {}
  local function tworfrom(word, i, ...)
    -- first we gotta pop 1, then pop another 1, then swap them.
    -- so we do a normal pop with a sentinel telling us to do the next pop
    -- then we do the next pop with a sentinel telling us to do the swap
    -- then we do the swap
    -- YES IT'S VERY PAINFUL

    if swap(...) == tworfromsentinel then
      -- next pop with sentinel for swap
      return word, 0, i - 1, tworfromswapsentinel, select(2, swap(...))
    elseif swap(...) == tworfromswapsentinel then
      -- the swap
      return word, i, swap(select(2, swap(...)))
    end
    -- normal pop with sentinel for next pop
    return word, 0, i - 1, tworfromsentinel, ...
  end
  cw["2R>"] = tworfrom

  -- fetch return stack (EVEN MORE PAINFUL)
  local function tworfetch(word, i, ...)
    if swap(...) == tworfromsentinel then
      -- next pop with sentinel for swap
      return word, 0, i - 1, tworfromswapsentinel, select(2, swap(...))
    elseif swap(...) == tworfromswapsentinel then
      -- the swap
      --return word, i, swap(select(2, swap(...)))
      local v1, v2 = swap(select(2, swap(...)))
      return twotor(word, i, v1, v2, swap(select(2, swap(...))))
    end
    -- normal pop with sentinel for next pop
    return word, 0, i - 1, tworfromsentinel, ...
  end
  cw["2R@"] = tworfetch
end

-- Constructs a new VM
local function new()
  -- char memory, used for byte buffers
  local charmem = ""
  -- aligned (cell-sized) memory
  local alignmem = {}
  -- string memory, used for strings with length
  local strmem = {}
end

return {words = cw, data = data, new = new}