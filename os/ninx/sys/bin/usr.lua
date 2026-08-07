-- usr.lua  Ninx user management command
-- Usage:
--   usr list
--   usr add "<name>" ["<password>"]
--   usr remove "<name>"
--   usr modify -p "<name>" "<newpassword>"
--   usr modify -u "<name>" "<newusername>"
--   usr modify -perm "<name>"
-- All add/remove/modify require sudo + root permission.

local U = dofile("/ninx/.sys/users.lua")

local function requireRoot()
  if U.isRoot() then return true end
  if not U.isSudoActive() then
    term.setTextColor(colors.red); print("usr: run with sudo: sudo usr ..."); term.setTextColor(colors.white)
    return false
  end
  if not U.hasPerm(U.currentUser(), "root") then
    term.setTextColor(colors.red); print("usr: root permission required."); term.setTextColor(colors.white)
    return false
  end
  return true
end

local function readPassword(prompt)
  io.write(prompt or "Password (blank=none): ")
  local buf = ""
  while true do
    local ev, ch = os.pullEvent()
    if ev == "char" then buf=buf..ch; io.write("*")
    elseif ev == "key" then
      if ch == keys.enter then print(); return buf
      elseif ch == keys.backspace and #buf > 0 then
        buf=buf:sub(1,-2)
        local x,y=term.getCursorPos()
        if x>1 then term.setCursorPos(x-1,y); io.write(" "); term.setCursorPos(x-1,y) end
      end
    end
  end
end

-- Permission selector UI
local PERM_DEFS = {
  { key="root",        label="Root access (su / full control)" },
  { key="sudo",        label="Use sudo command" },
  { key="sys_files",   label="Modify system files (with sudo)" },
  { key="other_users", label="Modify other users files (with sudo)" },
}
local function selectPerms(current)
  local sel = {}
  for _, pd in ipairs(PERM_DEFS) do
    sel[pd.key] = (current and current[pd.key] == true)
  end
  local cursor = 1
  local W,H = term.getSize()
  local function draw()
    term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
    term.setCursorPos(1,1)
    term.setBackgroundColor(colors.orange); term.setTextColor(colors.black)
    local t = "  [ Permission Selector ]  "
    term.setCursorPos(math.floor((W-#t)/2)+1,1); term.write(t)
    term.setBackgroundColor(colors.black); term.setTextColor(colors.gray)
    term.setCursorPos(2,3); print("  Up/Down=move  Space=toggle  Enter=confirm")
    for i, pd in ipairs(PERM_DEFS) do
      local checked = sel[pd.key] and "[x]" or "[ ]"
      term.setCursorPos(3, 4+i)
      if i == cursor then
        term.setBackgroundColor(colors.gray); term.setTextColor(colors.orange)
      else
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
      end
      term.write(checked .. " " .. pd.label .. string.rep(" ", W-8-#pd.label))
      term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
    end
  end
  draw()
  while true do
    local ev, key = os.pullEvent("key")
    if key == keys.up then cursor=cursor-1; if cursor<1 then cursor=#PERM_DEFS end
    elseif key == keys.down then cursor=cursor+1; if cursor>#PERM_DEFS then cursor=1 end
    elseif key == keys.space then sel[PERM_DEFS[cursor].key] = not sel[PERM_DEFS[cursor].key]
    elseif key == keys.enter then break end
    draw()
  end
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
  return sel
end

local function listUsers()
  local db = U.load()
  if #db == 0 then print("No users found."); return end
  print(string.format("%-16s %-8s %-8s %s", "Username", "Passwd", "Root", "Perms"))
  print(string.rep("-", 50))
  for _, u in ipairs(db) do
    local perms = {}
    if u.perms then
      for _, pd in ipairs(PERM_DEFS) do
        if u.perms[pd.key] then table.insert(perms, pd.key) end
      end
    end
    local hasPwd = u.hash and "yes" or "no"
    local isRoot = u.perms and u.perms.root and "yes" or "no"
    print(string.format("%-16s %-8s %-8s %s", u.name, hasPwd, isRoot, table.concat(perms,",")))
  end
end

-- ─── Main ─────────────────────────────────────────────────────────────────────
local args = {...}
if #args == 0 then
  print("Usage: usr [list|add|remove|modify]")
  print("  usr list")
  print("  usr add <name> [password]")
  print("  usr remove <name>")
  print("  usr modify -p <name> <newpassword>")
  print("  usr modify -u <name> <newusername>")
  print("  usr modify -perm <name>")
  return
end

local cmd = args[1]

if cmd == "list" then
  listUsers()

elseif cmd == "add" then
  if not requireRoot() then return end
  local name = args[2]
  if not name then print("Usage: usr add <name> [password]"); return end
  name = name:gsub('"','')
  if name:find("[^%w_%-]") then
    term.setTextColor(colors.red); print("Invalid username."); term.setTextColor(colors.white); return
  end
  local pwd = args[3] and args[3]:gsub('"','') or nil
  if not pwd then pwd = readPassword() end
  if pwd == "" then pwd = nil end

  -- Permission selection
  print("Select permissions for " .. name .. ":"); sleep(0.3)
  local perms = selectPerms(nil)
  local ok, err = U.create(name, pwd, perms)
  if ok then
    term.setTextColor(colors.green); print("User created: " .. name); term.setTextColor(colors.white)
  else
    term.setTextColor(colors.red); print(tostring(err)); term.setTextColor(colors.white)
  end

elseif cmd == "remove" then
  if not requireRoot() then return end
  local name = args[2] and args[2]:gsub('"','')
  if not name then print("Usage: usr remove <name>"); return end
  if name == U.currentUser() then
    term.setTextColor(colors.red); print("Cannot remove currently logged-in user."); term.setTextColor(colors.white); return
  end
  local ok, err = U.remove(name)
  if ok then
    term.setTextColor(colors.green); print("Removed user: " .. name); term.setTextColor(colors.white)
  else
    term.setTextColor(colors.red); print(tostring(err)); term.setTextColor(colors.white)
  end

elseif cmd == "modify" then
  if not requireRoot() then return end
  local flag = args[2]
  local name = args[3] and args[3]:gsub('"','')
  if not flag or not name then print("Usage: usr modify -p/-u/-perm <name> [value]"); return end

  if flag == "-p" then
    local newpwd = args[4] and args[4]:gsub('"','') or readPassword("New password: ")
    local hash = (newpwd == "") and nil or U.hashPassword(newpwd)
    local ok, err = U.update(name, { hash = hash })
    if ok then term.setTextColor(colors.green); print("Password updated."); term.setTextColor(colors.white)
    else term.setTextColor(colors.red); print(tostring(err)); term.setTextColor(colors.white) end

  elseif flag == "-u" then
    local newname = args[4] and args[4]:gsub('"','')
    if not newname then print("Usage: usr modify -u <name> <newusername>"); return end
    if newname:find("[^%w_%-]") then
      term.setTextColor(colors.red); print("Invalid username."); term.setTextColor(colors.white); return
    end
    local ok, err = U.update(name, { name = newname, home = "/ninx/usr/"..newname.."/home" })
    if ok then term.setTextColor(colors.green); print("Username updated."); term.setTextColor(colors.white)
    else term.setTextColor(colors.red); print(tostring(err)); term.setTextColor(colors.white) end

  elseif flag == "-perm" then
    local u = U.get(name)
    if not u then term.setTextColor(colors.red); print("User not found: "..name); term.setTextColor(colors.white); return end
    local perms = selectPerms(u.perms)
    local ok, err = U.update(name, { perms = perms })
    if ok then term.setTextColor(colors.green); print("Permissions updated."); term.setTextColor(colors.white)
    else term.setTextColor(colors.red); print(tostring(err)); term.setTextColor(colors.white) end

  else
    print("Unknown flag: " .. flag); print("Use -p (password), -u (username), or -perm")
  end

else
  print("Unknown command: " .. cmd)
  print("Usage: usr [list|add|remove|modify]")
end
