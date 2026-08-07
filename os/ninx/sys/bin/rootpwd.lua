-- rootpwd.lua  Set or change root password
-- Usage: rootpwd "<new password>"
-- Requires: current user to have root permission

local U = dofile("/ninx/.sys/users.lua")

if not U.hasPerm(U.currentUser(), "root") and not U.isRoot() then
  term.setTextColor(colors.red)
  print("rootpwd: permission denied - root permission required.")
  term.setTextColor(colors.white)
  return
end

local function readPassword(prompt)
  io.write(prompt or "New root password: ")
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

local args = {...}
local pwd1, pwd2

if args[1] then
  -- Passed as argument (not recommended but supported)
  pwd1 = args[1]; pwd2 = args[1]
else
  pwd1 = readPassword("New root password: ")
  pwd2 = readPassword("Confirm password: ")
end

if pwd1 ~= pwd2 then
  term.setTextColor(colors.red); print("Passwords do not match."); term.setTextColor(colors.white)
  return
end

if pwd1 == "" then
  term.setTextColor(colors.orange); print("Root password cleared (no password required).")
  U.setRootPassword("")
  term.setTextColor(colors.white)
else
  U.setRootPassword(pwd1)
  term.setTextColor(colors.green); print("Root password updated."); term.setTextColor(colors.white)
end
