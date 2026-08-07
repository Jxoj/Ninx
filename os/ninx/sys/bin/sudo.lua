-- sudo.lua  Ninx sudo - run command with elevated permissions
-- Usage: sudo <command> [args...]

local U = dofile("/ninx/.sys/users.lua")

local args = {...}
if #args == 0 then
  print("Usage: sudo <command> [args...]")
  return
end

-- Check if current user can use sudo
if not U.canSudo() then
  term.setTextColor(colors.red)
  print("sudo: " .. U.currentUser() .. " is not allowed to use sudo.")
  print("Contact an administrator or use a user with sudo permission.")
  term.setTextColor(colors.white)
  return
end

-- Build command to run
local cmd = args[1]
local cmdArgs = {}
for i = 2, #args do cmdArgs[#cmdArgs+1] = args[i] end

-- Set sudo flag
_G.NINX_SUDO = true

-- Look up in bin first
local BIN_DIR = "/ninx/.sys/bin"
local binPath = BIN_DIR .. "/" .. cmd .. ".lua"

local function run(path, a)
  local ok, err = pcall(function()
    if #a > 0 then shell.run(path, table.unpack(a))
    else shell.run(path) end
  end)
  _G.NINX_SUDO = false
  if not ok then
    term.setTextColor(colors.red); print("sudo: " .. tostring(err)); term.setTextColor(colors.white)
  end
end

if fs.exists(binPath) then
  run(binPath, cmdArgs)
elseif fs.exists(cmd) then
  run(cmd, cmdArgs)
else
  -- Try shell.run (will search CraftOS ROM too)
  local ok, err = pcall(function()
    if #cmdArgs > 0 then shell.run(cmd, table.unpack(cmdArgs))
    else shell.run(cmd) end
  end)
  _G.NINX_SUDO = false
  if not ok then
    term.setTextColor(colors.red); print("sudo: command not found or error: " .. tostring(err))
    term.setTextColor(colors.white)
  end
end
