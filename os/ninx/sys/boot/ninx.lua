-- ninx.lua  Ninx Boot Entry Point
-- Called by bootmenu when "Ninx" option is selected.
-- Handles: setup (first boot) → login → desktop

local function colourPrint(tag, tagColor, msg)
  term.setTextColor(colors.white); io.write("[")
  term.setTextColor(tagColor); io.write(tag)
  term.setTextColor(colors.white); io.write("] "); print(msg)
end

-- ─── User management: setup or login ──────────────────────────────────────────
local function runUserSystem()
  -- Load users library
  local ok, U = pcall(dofile, "/ninx/.sys/users.lua")
  if not ok then
    colourPrint("Warn", colors.orange, "users.lua not found, skipping login")
    _G.NINX_USER = "guest"; _G.NINX_ROOT = false; _G.NINX_SUDO = false
    _G.NINX_CWD  = "/ninx/usr/guest/home"
    if not fs.exists(_G.NINX_CWD) then fs.makeDir(_G.NINX_CWD) end
    return
  end

  if U.isFirstBoot() then
    colourPrint("Info", colors.yellow, "First boot — launching setup...")
    sleep(0.5)
    local ok2, err2 = pcall(function() shell.run("/ninx/.sys/boot/setup.lua") end)
    if not ok2 then
      colourPrint("Error", colors.red, "Setup failed: " .. tostring(err2)); sleep(2)
    end
  end

  -- Login
  local ok3, err3 = pcall(function() shell.run("/ninx/.sys/boot/login.lua") end)
  if not ok3 then
    colourPrint("Error", colors.red, "Login failed: " .. tostring(err3))
    _G.NINX_USER = "guest"; _G.NINX_ROOT = false; _G.NINX_SUDO = false
    _G.NINX_CWD  = "/ninx/usr/guest/home"
    if not fs.exists(_G.NINX_CWD) then fs.makeDir(_G.NINX_CWD) end
    sleep(1)
  end
end

runUserSystem()

-- ─── Boot-time package update check ──────────────────────────────────────────
local function bootUpdateCheck()
  local PKG_DIR   = "/ninx/packages"
  local REPOS_CFG = "/ninx/.sys/config/nam.cfg"
  if not fs.exists(PKG_DIR) or not http then return end

  -- Quick version check without printing much
  local function readMeta(id)
    local dir = PKG_DIR .. "/" .. id
    if not fs.exists(dir) then return nil end
    local ok, list = pcall(fs.list, dir)
    if not ok then return nil end
    for _, f in ipairs(list) do
      if f:match("^com%.") and f:sub(-5) == ".json" then
        local fh = fs.open(dir.."/"..f,"r"); if not fh then break end
        local raw=fh.readAll(); fh.close()
        local ok2,t=pcall(textutils.unserializeJSON,raw)
        if ok2 and t then return t end
      end
    end
    return nil
  end

  local function verCompare(a,b)
    a=tostring(a or "0"); b=tostring(b or "0")
    local function p(v) local t={} for n in v:gmatch("%d+") do t[#t+1]=tonumber(n) or 0 end return t end
    local ap,bp=p(a),p(b); local len=math.max(#ap,#bp)
    for i=1,len do local av=ap[i] or 0; local bv=bp[i] or 0; if av<bv then return -1 end; if av>bv then return 1 end end
    return 0
  end

  -- Build repo index quietly
  local repos = {}
  if fs.exists(REPOS_CFG) then
    local f=fs.open(REPOS_CFG,"r"); if f then
      while true do local l=f.readLine(); if not l then break end
        l=l:match("^%s*(.-)%s*$"); if l~="" then repos[#repos+1]=l end
      end
      f.close()
    end
  end
  if #repos == 0 then return end

  local index = {}
  for _, url in ipairs(repos) do
    local ok, res = pcall(function() return http.get(url) end)
    if ok and res then
      local body = res.readAll(); res.close()
      local ok2, parsed = pcall(textutils.unserializeJSON, body)
      if ok2 and type(parsed)=="table" then
        for _, pkg in ipairs(parsed) do if pkg.id then index[pkg.id]=pkg end end
      end
    end
  end

  -- Check installed packages
  local updates = {}
  local ok2, list = pcall(fs.list, PKG_DIR)
  if not ok2 then return end
  for _, dir in ipairs(list) do
    local meta = readMeta(dir)
    if meta and meta.id and index[meta.id] then
      if verCompare(meta.version, index[meta.id].version) < 0 then
        updates[#updates+1] = dir .. " (" .. (meta.version or "?") .. " → " .. (index[meta.id].version or "?") .. ")"
      end
    end
  end

  if #updates > 0 then
    term.setTextColor(colors.orange)
    print("[NAM] " .. #updates .. " package update(s) available:")
    term.setTextColor(colors.gray)
    for _, u in ipairs(updates) do print("  • " .. u) end
    print("  Run 'sudo nam update' to upgrade.")
    term.setTextColor(colors.white)
    sleep(2)
  end
end

pcall(bootUpdateCheck)


local function getWindowManager()
  local path = "/ninx/.sys/config/sys.cfg"
  if not fs.exists(path) then return "Default" end
  local file = fs.open(path, "r"); if not file then return "Default" end
  local manager = "Default"
  while true do
    local line = file.readLine(); if not line then break end
    local key, value = line:match("^(%S+):%s*(%S+)$")
    if key == "Windowmanger" or key == "Windowmanager" then manager = value; break end
  end
  file.close(); return manager
end

local wm = getWindowManager()
local script = "/ninx/.sys/boot/desktop/workspace.lua"
if wm == "Graphical" then script = "/ninx/.sys/boot/desktop/gwm.lua" end

colourPrint("Success", colors.green, "Attempting to start workspace (" .. wm .. " mode).")

local ok, err = pcall(function() shell.run("/ninx/.sys/utils/loading.lua", script) end)
if ok then
  colourPrint("Success", colors.green, "Workspace exited cleanly.")
  sleep(0.5)
  return
end

colourPrint("Error", colors.red, "Failed to start workspace: " .. tostring(err))
sleep(0.5)
colourPrint("Info", colors.yellow, "Falling back to BIOS...")
local ok2, err2 = pcall(function() shell.run("/ninx/.sys/bios.lua") end)
if not ok2 then
  colourPrint("Error", colors.red, "BIOS fallback failed: " .. tostring(err2))
  sleep(1)
end