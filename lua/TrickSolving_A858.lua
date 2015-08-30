local data = {
  -- yes it does have a space, between the 9 and the !.
  alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !@#%&*([{</?,.'+-_|`^~ulcmx",
  ucase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  lcase = "abcdefghijklmnopqrstuvwxyz",
  hexno = "0123456789ABCDEF",
  decno = "0123456789",
  symbols = " !@#%&*([{</?,.'+-_|`^~",
  upper = "u",
  lower = "l",
  combine = "c",
  mirror = "m",
  unicode = "x",
  combos = { -- TODO: adding combos is a pain, make it easier
    ["'"]={["'"]='"',},
    ["S"]={["|"]="$",},
    ["."]={["."]=":",[","]=";",},
    ["-"]={["-"]="=",},
  },
  mirrors = {
    ["{"]="}",
    ["["]="]",
    ["("]=")",
    ["<"]=">",
    ["`"] = "´", -- TODO: needs unicode handling
    ["/"] = "\\", -- I did this to avoid typing double-\s
  },
  backmirrors = {}, -- initialized below
  backcombos = {}, -- initialized below
  utol = {}, -- initialized below
  ltou = {}, -- initialized below
}
do
  -- finish initialization of the above
  local mirrors, backmirrors = data.mirrors, data.backmirrors
  for n,m in pairs(mirrors) do
    -- [n]ormal, [m]irrored
    backmirrors[m] = n .. 'm'
  end

  local combos, backcombos = data.combos, data.backcombos
  for a, bs in pairs(combos) do
    -- "bs" as in "multiple of b"
    for b, c in pairs(bs) do
      -- [c]ombined
      backcombos[c] = a .. b .. 'c'
    end
  end
  
  local ucase, lcase = data.ucase, data.lcase
  local utol, ltou = data.utol, data.ltou
  assert(#ucase == #lcase, "bad case mappings")
  for i=1, #ucase do
    local uc, lc = ucase:sub(i,i), lcase:sub(i,i)
    utol[uc], ltou[lc] = lc, uc
  end
end

if #data.alphabet ~= 64 then
  error("bad alphabet" .. tostring(data.alphabet) .. tostring(#data.alphabet))
  return
end
local tAB = {}
local tBA = {}
for i, v in string.gmatch(data.alphabet, "()(.)") do
  assert(not tBA[v], "Duplicated mapping")
  tAB[v] = i
  tBA[i] = v
end

local k = tAB[arg[2]]
local str
local writeout
if arg[3] then
  str = table.concat(arg, " ", 3, #arg)
else
  str = io.read("*a")
  -- no trailing newline
  if string.sub(str, -1, -1) == "\n" then str = string.sub(str, 1, -2) end
end

if arg[1]:sub(1,1) == "e" then
  local tnstr = {}
  local cur = 0 -- also (table) length
  local case = false
  local function toiterf(a,b,c) -- helper so we can skip chars
    local function helper(...)
      c = ...
      return ...
    end
    return function()
      return helper(a(b, c))
    end
  end
  local iter = toiterf(string.gmatch(str, "()(.)"))
  for i, v in iter do
    if data.ucase:find(v, 1, true) then
      if case then
        case = false
        cur = cur + 1
        tnstr[cur] = "u"
      end
      cur = cur + 1
      tnstr[cur] = v
    elseif data.lcase:find(v, 1, true) then
      if not case then
        case = true
        cur = cur + 1
        tnstr[cur] = "l"
      end
      cur = cur + 1
      tnstr[cur] = data.ltou[v]
    elseif data.symbols:find(v, 1, true) or data.decno:find(v, 1, true) then
      cur = cur + 1
      tnstr[cur] = v
    elseif data.backmirrors[v] then
      cur = cur + 1
      tnstr[cur] = data.backmirrors[v]
    elseif data.backcombos[v] then
      cur = cur + 1
      tnstr[cur] = data.backcombos[v]
    -- unicode (2 chars)
    elseif string.find(str, "^[\xC2-\xDF][\x80-\xBF]", i) == i then
      iter() -- skip next char
      local x = utf8.codepoint(string.match(str, "^[\xC2-\xDF][\x80-\xBF]", i))
      cur = cur + 1
      tnstr[cur] = string.format("|%X|x", x) -- e.g. |A2|x = U+00A2
    -- unicode (3 chars)
    elseif string.find(str, "^[\xE0-\xEF][\x80-\xBF][\x80-\xBF]", i) == i then
      iter() iter() -- skip next 2 chars
      local x = utf8.codepoint(string.match(str, "^[\xE0-\xEF][\x80-\xBF][\x80-\xBF]", i))
      cur = cur + 1
      tnstr[cur] = string.format("|%X|x", x) -- e.g. |20AC|x = U+20AC
    -- unicode (4 chars)
    elseif string.find(str, "^[\xF0-\xF4][\x80-\xBF][\x80-\xBF][\x80-\xBF]", i) == i then
      iter() iter() iter() -- skip next 3 chars
      local x = utf8.codepoint(string.match(str, "^[\xF0-\xF4][\x80-\xBF][\x80-\xBF][\x80-\xBF]", i))
      cur = cur + 1
      tnstr[cur] = string.format("|%X|x", x) -- e.g. |10348|x = U+10348
    else -- raw byte
      cur = cur + 1
      tnstr[cur] = string.format("%02Xx", string.byte(v))
    end
  end

  local nstr = table.concat(tnstr, "", 1, cur)

  local last = 0
  local alphalen = #data.alphabet
  local new = {}
  local cur = 0
  for i, v in string.gmatch(nstr, "()(.)") do
    last = (tAB[v] + last + k) % alphalen + 1
    cur = cur + 1
    new[cur] = tBA[last]
  end

  local final = table.concat(new, "", 1, cur)
  print(final)
elseif arg[1]:sub(1,1) == "d" then
  local alphalen = #data.alphabet
  local last
  local new = {}
  local cur = 0
  local case = false
  local surrogate = false
  local function hextono(x)
    return (data.hexno:find(data.ltou[x] or x, 1, true) or error("Not a valid hexadecimal digit")) - 1
  end
  for i, v in string.gmatch(str, "()(.)") do
    local t = tAB[last] or 0
    local char = tAB[v]
    char = char - t
    char = char - k
    char = char - 2
    char = char % alphalen + 1 -- TODO adjust
    local nv = tBA[char] or error("Invalid ciphertext")
    last = v
    if nv == "x" then
      if new[cur] ~= "|" then -- raw byte
        local x1, x2 = new[cur - 1], new[cur]
        new[cur] = nil
        cur = cur - 1
        new[cur] = string.char(hextono(x1) * 0x10 + hextono(x2))
      else -- unicode
        local v = {}
        for i=cur-1, cur-7, -1 do
          if new[i] == "|" then break end
          if new[i] ~= "|" and i == cur-8 then error("Not a valid unicode escape") end
          table.insert(v,hexton(new[i]))
        end
        local n = 0
        for i,v in ipairs(v) do
          n = n + v * 2^(i-1)
        end
        for i=cur, cur-#v, -1 do
          cur = i
          new[cur] = nil
        end
        cur = cur - 1
        new[cur] = utf8.char(n)
      end
    elseif nv == "l" then
      case = true
    elseif nv == "u" then
      case = false
    elseif nv == "c" then
      local a = new[cur - 1]
      local b = new[cur]
      new[cur] = nil
      cur = cur - 1
      local combos = data.combos
      if combos[a] then
        new[cur] = combos[a][b] or error("Invalid ciphertext")
      elseif combos[b] then
        new[cur] = combos[b][a] or error("Invalid ciphertext")
      else
        error("Invalid ciphertext")
      end
    elseif nv == "m" then
      new[cur] = data.mirrors[new[cur]] or error("Invalid ciphertext")
    else
      if case then
        nv = data.utol[nv] or nv
      end
      cur = cur + 1
      new[cur] = nv
    end
  end
  print(table.concat(new, "", 1, cur))
end
