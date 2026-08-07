

local shell = shell or _G.shell
local unpack = table.unpack or unpack
local args = {...}
if #args == 0 then
  return shell.run("copy")
else
  return shell.run("copy", unpack(args))
end