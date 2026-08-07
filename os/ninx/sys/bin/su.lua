-- su.lua  Ninx su - switch to root
-- Usage: su
-- Prompts for root password, then sets NINX_ROOT = true and relaunches shell.

local U = dofile("/ninx/.sys/users.lua")

-- Check user has root permission
if not U.hasPerm(U.currentUser(), "root") then
  term.setTextColor(colors.red)
  print("su: permission denied - user '" .. U.currentUser() .. "' does not have root permission.")
  term.setTextColor(colors.white)
  return
end

-- Read root password with * masking
local function readPassword(prompt)
  io.write(prompt or "Root password: ")
  local buf = ""
  while true do
    local ev, ch = os.pullEvent()
    if ev == "char" then buf = buf .. ch; io.write("*")
    elseif ev == "key" then
      if ch == keys.enter then print(); return buf
      elseif ch == keys.backspace and #buf > 0 then
        buf = buf:sub(1,-2)
        local x,y = term.getCursorPos()
        if x > 1 then term.setCursorPos(x-1,y); io.write(" "); term.setCursorPos(x-1,y) end
      end
    end
  end
end

term.setTextColor(colors.orange); print("[su] Switching to root"); term.setTextColor(colors.white)

local attempts = 3
local ok = false
while attempts > 0 do
  local pwd = readPassword()
  local authed, _ = U.authenticateRoot(pwd)
  if authed then ok = true; break end
  attempts = attempts - 1
  term.setTextColor(colors.red)
  print("Wrong password" .. (attempts > 0 and (" - " .. attempts .. " attempt(s) remaining") or "."))
  term.setTextColor(colors.white)
end

if not ok then
  term.setTextColor(colors.red); print("su: authentication failure"); term.setTextColor(colors.white)
  return
end

-- Save previous session
local prevUser = _G.NINX_USER
local prevCwd  = _G.NINX_CWD

_G.NINX_USER = "root"
_G.NINX_ROOT = true
_G.NINX_SUDO = true
_G.NINX_CWD  = "/ninx"

term.setTextColor(colors.orange); print("[su] You are now root. Type 'exit' to return.")
term.setTextColor(colors.white)

-- Launch a nested shell session
local ok2, err2 = pcall(function() shell.run("/ninx/.sys/shell.lua") end)

-- Restore session
_G.NINX_USER = prevUser
_G.NINX_ROOT = false
_G.NINX_SUDO = false
_G.NINX_CWD  = prevCwd

term.setTextColor(colors.orange); print("[su] Returned to " .. (prevUser or "guest"))
term.setTextColor(colors.white)
