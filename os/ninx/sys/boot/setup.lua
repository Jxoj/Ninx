-- setup.lua  Ninx First-Boot Setup Wizard
-- Called by ninx.lua when no users exist yet.
-- Creates initial user accounts and sets root password.

local U = dofile("/ninx/.sys/users.lua")

local W, H = term.getSize()
local C_BG     = colors.black
local C_FG     = colors.white
local C_ACCENT = colors.orange
local C_SEL_BG = colors.orange
local C_SEL_FG = colors.black
local C_DIM    = colors.gray
local C_ERR    = colors.red

local function clr()
  term.setBackgroundColor(C_BG); term.setTextColor(C_FG); term.clear()
end
local function center(y, text, fg, bg)
  bg = bg or C_BG; fg = fg or C_FG
  local x = math.max(1, math.floor((W-#text)/2)+1)
  term.setCursorPos(x,y); term.setBackgroundColor(bg)
  term.setTextColor(fg); term.write(text)
  term.setBackgroundColor(C_BG); term.setTextColor(C_FG)
end
local function p(text, fg) term.setTextColor(fg or C_FG); print(text); term.setTextColor(C_FG) end
local function pw(text, fg) term.setTextColor(fg or C_FG); io.write(text); term.setTextColor(C_FG) end

-- Secure password read (shows *)
local function readPassword(prompt)
  pw(prompt or "Password (leave blank for none): ")
  local buf = ""
  while true do
    local ev, ch = os.pullEvent()
    if ev == "char" then
      buf = buf .. ch
      io.write("*")
    elseif ev == "key" then
      if ch == keys.enter then print(); return buf
      elseif ch == keys.backspace and #buf > 0 then
        buf = buf:sub(1,-2)
        local x,y = term.getCursorPos()
        if x > 1 then
          term.setCursorPos(x-1,y); io.write(" "); term.setCursorPos(x-1,y)
        end
      end
    end
  end
end

-- Permission selector
local PERM_DEFS = {
  { key="root",        label="Root access (use su, full control)" },
  { key="sudo",        label="Use sudo command" },
  { key="sys_files",   label="Modify system files (with sudo)" },
  { key="other_users", label="Modify other users' files (with sudo)" },
}

local function selectPerms(forFirst)
  local sel = {}
  -- Defaults
  for _, p in ipairs(PERM_DEFS) do
    if forFirst then sel[p.key] = (p.key == "root" or p.key == "sudo")
    else sel[p.key] = false end
  end

  local cursor = 1
  local function draw()
    clr()
    center(1, "[ Permission Selector ]", C_SEL_FG, C_SEL_BG)
    p("", C_DIM)
    p("  Space=toggle  Enter=confirm", C_DIM)
    p("")
    for i, pd in ipairs(PERM_DEFS) do
      local checked = sel[pd.key] and "[x]" or "[ ]"
      local fg = (i == cursor) and C_ACCENT or C_FG
      local bg = (i == cursor) and colors.gray or C_BG
      term.setCursorPos(3, 4+i)
      term.setBackgroundColor(bg); term.setTextColor(fg)
      print(checked .. " " .. pd.label)
      term.setBackgroundColor(C_BG); term.setTextColor(C_FG)
    end
  end

  draw()
  while true do
    local ev, key = os.pullEvent("key")
    if key == keys.up then cursor = cursor - 1; if cursor < 1 then cursor = #PERM_DEFS end
    elseif key == keys.down then cursor = cursor + 1; if cursor > #PERM_DEFS then cursor = 1 end
    elseif key == keys.space then sel[PERM_DEFS[cursor].key] = not sel[PERM_DEFS[cursor].key]
    elseif key == keys.enter then break end
    draw()
  end
  return sel
end

-- Show created users list
local function showUsers()
  local db = U.load()
  if #db == 0 then
    p("  (no users created yet)", C_DIM)
  else
    for _, u in ipairs(db) do
      local permbadges = {}
      if u.perms and u.perms.root  then table.insert(permbadges,"root") end
      if u.perms and u.perms.sudo  then table.insert(permbadges,"sudo") end
      local badge = #permbadges > 0 and (" [" .. table.concat(permbadges,",") .. "]") or ""
      local hasPasswd = u.hash and "password set" or "no password"
      p("  • " .. u.name .. badge .. "  (" .. hasPasswd .. ")", C_FG)
    end
  end
end

-- ─── Main setup loop ──────────────────────────────────────────────────────────
clr()
center(1, "  NINX FIRST-BOOT SETUP  ", C_SEL_FG, C_SEL_BG)
p(""); p(""); p("")
center(4, "Welcome to Ninx!", C_ACCENT)
p("")
p("  Let's create your user account.", C_DIM)
p("  The first user will have root and sudo permissions.", C_DIM)
p("")
p("  Press Enter to continue...")
read()

local function createUserFlow(isFirst)
  while true do
    clr()
    center(1, "  CREATE USER  ", C_SEL_FG, C_SEL_BG)
    p(""); p("")

    -- Show existing users
    p("Existing users:", C_ACCENT)
    showUsers()
    p("")

    pw("Username: ", C_ACCENT)
    local name = read()
    if not name or name:match("^%s*$") then
      p("Cancelled.", C_DIM); sleep(1); return false
    end
    name = name:match("^%s*(.-)%s*$")
    if name:find("[^%w_%-]") then
      p("Invalid username. Use only letters, numbers, _ -", C_ERR); sleep(2); break
    end
    if U.get(name) then
      p("User already exists!", C_ERR); sleep(2); break
    end

    local pwd = readPassword()
    local perms
    if isFirst then
      p("Setting default root permissions for first user.", C_DIM)
      perms = { root=true, sudo=true, sys_files=false, other_users=false }
    else
      p("Select permissions for " .. name .. ":", C_ACCENT)
      sleep(0.5)
      perms = selectPerms(false)
    end

    local ok, err = U.create(name, pwd == "" and nil or pwd, perms)
    if ok then
      clr()
      center(1, "  USER CREATED  ", C_SEL_FG, C_SEL_BG)
      p(""); p("")
      p("  Created user: " .. name, C_ACCENT)
      p("  Home: /ninx/usr/" .. name .. "/home", C_DIM)
      sleep(1.5)
      return true
    else
      p("Error: " .. tostring(err), C_ERR); sleep(2)
    end
    break
  end
  return false
end

-- Create first mandatory user
createUserFlow(true)

-- Ask to create more users
while true do
  clr()
  center(1, "  NINX SETUP  ", C_SEL_FG, C_SEL_BG)
  p(""); p("")
  p("Current users:", C_ACCENT)
  showUsers()
  p("")
  p("Would you like to add another user? (y/n)", C_FG)
  local ans = read()
  if not ans or ans:lower():sub(1,1) ~= "y" then break end
  createUserFlow(false)
end

-- Offer to set root password
clr()
center(1, "  ROOT PASSWORD  ", C_SEL_FG, C_SEL_BG)
p(""); p("")
p("The root account can be accessed via the 'su' command.", C_DIM)
p("Would you like to set a root password? (y/n)", C_FG)
local ans = read()
if ans and ans:lower():sub(1,1) == "y" then
  local pwd1 = readPassword("Root password: ")
  local pwd2 = readPassword("Confirm: ")
  if pwd1 == pwd2 and pwd1 ~= "" then
    U.setRootPassword(pwd1)
    p("Root password set.", C_ACCENT)
  else
    p("Passwords didn't match. Root password not set.", C_ERR)
  end
  sleep(1.5)
end

-- Done
clr()
center(H/2-1, "Setup complete!", C_ACCENT)
center(H/2,   "Booting Ninx...", C_DIM)
sleep(2)
