-- login.lua  Ninx User Login / Selection Screen
-- Shown on every boot (after first-boot setup).
-- Sets _G.NINX_USER, _G.NINX_ROOT, _G.NINX_CWD before returning.

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
local function pw(text, fg)
  term.setTextColor(fg or C_FG); io.write(text); term.setTextColor(C_FG)
end

-- Read password with * masking
local function readPassword()
  local buf = ""
  while true do
    local ev, ch = os.pullEvent()
    if ev == "char" then
      buf = buf .. ch; io.write("*")
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

-- ─── User selection menu ──────────────────────────────────────────────────────
local function selectUser()
  local db = U.load()
  if #db == 0 then
    clr()
    center(H/2, "No users found. Run setup.", C_ERR)
    sleep(3)
    return nil
  end

  local sel  = 1
  local function draw()
    clr()
    center(2, "NINX LOGIN", C_SEL_FG, C_SEL_BG)
    center(4, "Use Up/Down arrows and Enter to select user", C_DIM)
    for i, u in ipairs(db) do
      local y = 6 + (i-1)
      term.setCursorPos(math.floor(W/2)-8, y)
      if i == sel then
        term.setBackgroundColor(C_SEL_BG); term.setTextColor(C_SEL_FG)
        term.write(" > " .. u.name .. string.rep(" ", 14-#u.name) .. " ")
        term.setBackgroundColor(C_BG); term.setTextColor(C_FG)
      else
        term.setTextColor(C_FG)
        term.write("   " .. u.name)
      end
    end
    center(H-1, "Arrows=select  Enter=login", C_DIM)
  end

  draw()
  while true do
    local ev, key = os.pullEvent("key")
    if key == keys.up    then sel = sel-1; if sel<1 then sel=#db end
    elseif key == keys.down then sel = sel+1; if sel>#db then sel=1 end
    elseif key == keys.enter then return db[sel] end
    draw()
  end
end

-- ─── Password entry ───────────────────────────────────────────────────────────
local function loginUser(u)
  if not u.hash then
    -- No password, log right in
    return true
  end
  -- Attempt password
  local attempts = 3
  while attempts > 0 do
    clr()
    center(2, "NINX LOGIN", C_SEL_FG, C_SEL_BG)
    center(4, "User: " .. u.name, C_ACCENT)
    center(6, "Enter password (" .. attempts .. " attempts remaining)", C_DIM)
    term.setCursorPos(math.floor(W/2)-8, 8)
    pw("Password: ", C_FG)
    local pwd = readPassword()
    local ok, _ = U.authenticate(u.name, pwd)
    if ok then return true end
    attempts = attempts - 1
    center(10, "Wrong password!", C_ERR)
    sleep(1.5)
  end
  center(12, "Too many failed attempts.", C_ERR)
  sleep(2)
  return false
end

-- ─── Main ─────────────────────────────────────────────────────────────────────
while true do
  local user = selectUser()
  if not user then break end

  local ok = loginUser(user)
  if ok then
    -- Set session globals
    _G.NINX_USER = user.name
    _G.NINX_ROOT = false
    _G.NINX_SUDO = false
    _G.NINX_CWD  = user.home or ("/ninx/usr/" .. user.name .. "/home")
    -- Ensure home dir exists
    if not fs.exists(_G.NINX_CWD) then fs.makeDir(_G.NINX_CWD) end

    clr()
    center(H/2-1, "Welcome, " .. user.name .. "!", C_ACCENT)
    center(H/2,   "Loading Ninx...", C_DIM)
    sleep(1)
    break
  end
  -- Failed login: loop back to user selection
end
