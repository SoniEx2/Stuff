--[[
long comment
]]

--[==[
level 2 long comment
]==]

s = "string"

ls = [[
long string - why does this show up as a comment on the editor?
]]

l2ls = [==[
level 2 long string - also shows up as comment on the editor
]==]

mls = "multi\
line\
string" -- doesn't show up properly on the editor

fcall(s)
fcall_s"string"
fcall_t{s}
fcall_ls[[
long string - also shows up as comment on the editor
]]
fcall_l2ls[==[
level 2 long string - also shows up as comment on the editor
]==]
fcall_mls"multi\
line\
string" -- doesn't show up properly on the editor

indexed.fcall(s)
indexed.fcall_s"string"
indexed.fcall_t{s}
indexed.fcall_ls[[
long string - also shows up as comment on the editor
]]
indexed.fcall_l2ls[==[
level 2 long string - also shows up as comment on the editor
]==]
indexed.fcall_mls"multi\
line\
string" -- doesn't show up properly on the editor

ffi.cdef[[
typedef union my_union {
  uint8_t *ub;
  int8_t *b;
  uint16_t *uw;
  int16_t *w;
  uint32_t *ul;
  int32_t *l; // c comment
} my_union_t;
]]

cdef[[
typedef union my_union {
  uint8_t *ub;
  int8_t *b;
  uint16_t *uw;
  int16_t *w;
  uint32_t *ul;
  int32_t *l; // c comment
} my_union_t;
]]

cls = [[
typedef union my_union {
  uint8_t *ub;
  int8_t *b;
  uint16_t *uw;
  int16_t *w;
  uint32_t *ul;
  int32_t *l; // c comment
} my_union_t;
]]
