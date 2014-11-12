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
