-- Based on a modified table deepcopy function
local function scan(_table, _type, _callback, _userdata)
  local todo = {[_table] = true}
  local seen = {}
  local path = {}
  -- we can't use pairs() here because we modify todo
  while next(todo) do
    local t = next(todo)
    todo[t] = nil
    seen[t] = true
    for k, v in next, t do
      -- ignore type check if _type = nil (the value nil, not the string "nil")
      if not _type or type(v) == _type then
        _callback(t, k, v, _userdata)
      end
      if not seen[k] and type(k) == "table" then
        todo[k] = true
      end
      if not seen[v] and type(v) == "table" then
        todo[v] = true
      end
    end
  end
end
