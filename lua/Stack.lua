-- Stacks. Because why not!

-- Stack-based table.unpack
local function unpack(t, i, j)
  local function unpack_impl(t, i, j, ...)
    if i == j then return t[j], ... end
    return unpack_impl(t, i, j - 1, t[j], ...)
  end
  return unpack_impl(t, i or 1, j or #t)
end