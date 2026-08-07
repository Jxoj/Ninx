local fs, http, textutils, shell = fs, http, textutils, shell
local DEFAULT_REPO = "https://jxoj.github.io/Ninx/packages/pkgs.json"
local REPO_PATH = "/ninx/.sys/config/nam.cfg"
local REPO_DIR = "/ninx/.sys/config"
local PKG_DIR = "/ninx/packages"
local GUI_SUBDIR = "gui"
local GUI_DIR = PKG_DIR .. "/" .. GUI_SUBDIR

local function ensureDir(path)
  -- Ensure directory for a file path exists. This behaves like original:
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

local function ensureConfig()
  if not fs.exists(REPO_DIR) then fs.makeDir(REPO_DIR) end
  if not fs.exists(REPO_PATH) then
    local f = fs.open(REPO_PATH, "w")
    if f then f.write(DEFAULT_REPO .. "\n"); f.close() end
  end
  if not fs.exists(PKG_DIR) then fs.makeDir(PKG_DIR) end
  if not fs.exists(GUI_DIR) then fs.makeDir(GUI_DIR) end
end

local function readRepo()
  ensureConfig()
  local f = fs.open(REPO_PATH, "r")
  if not f then return DEFAULT_REPO end
  local s = f.readAll() or ""; f.close()
  s = s:gsub("%s+$", "")
  if s == "" then return DEFAULT_REPO end
  return s
end

local function writeRepo(url)
  ensureConfig()
  local f = fs.open(REPO_PATH, "w")
  if not f then return false, "cannot open repo file" end
  f.write((url or DEFAULT_REPO) .. "\n")
  f.close(); return true
end

local function fetchIndex()
  local url = readRepo()
  if not http then error("HTTP API disabled") end
  local res = http.get(url)
  if not res then error("Cannot fetch package index: " .. url) end
  local body = res.readAll(); res.close()
  local ok, parsed = pcall(textutils.unserializeJSON, body)
  if not ok or type(parsed) ~= "table" then error("Invalid package index JSON") end
  return parsed
end

-- Check installed in either root packages or gui subdir
local function isInstalled(name)
  local rootPath = PKG_DIR .. "/" .. name .. ".lua"
  local guiPath = GUI_DIR .. "/" .. name .. ".lua"
  return fs.exists(rootPath) or fs.exists(guiPath)
end

local function listInstalled()
  if not fs.exists(PKG_DIR) then return {} end
  local seen = {}
  local out = {}
  -- root package files
  for _, f in ipairs(fs.list(PKG_DIR)) do
    if f:sub(-4) == ".lua" then
      local n = f:sub(1, -5)
      if not seen[n] then seen[n] = true; table.insert(out, n) end
    end
  end
  -- gui subdir packages (if present)
  if fs.exists(GUI_DIR) and fs.isDirectory and fs.isDirectory(GUI_DIR) or (fs.list and #fs.list(GUI_DIR) > 0) then
    for _, f in ipairs(fs.list(GUI_DIR)) do
      if f:sub(-4) == ".lua" then
        local n = f:sub(1, -5)
        if not seen[n] then seen[n] = true; table.insert(out, n) end
      end
    end
  end
  table.sort(out)
  return out
end

local function download(url)
  local res, err = http.get(url)
  if not res then error("Download failed: " .. tostring(err or url)) end
  local data = res.readAll(); res.close(); return data
end

local function installOne(index, name, visited)
  visited = visited or {}
  if visited[name] then return end
  visited[name] = true
  local info = index[name]
  if not info then error("No such package: " .. name) end

  -- handle dependency list if present
  if info.durl then
    local ok, depsJson = pcall(download, info.durl)
    if ok and depsJson and #depsJson > 0 then
      local ok2, deps = pcall(textutils.unserializeJSON, depsJson)
      if ok2 and type(deps) == "table" then
        for _, dep in ipairs(deps) do installOne(index, dep, visited) end
      end
    end
  end

  if isInstalled(name) then return end

  local data = download(info.url)

  -- Decide target directory based on package type
  local targetDir = PKG_DIR
  local installedToGui = false
  if type(info.type) == "string" and info.type:lower() == "gui" then
    targetDir = GUI_DIR
    installedToGui = true
  end

  ensureDir(targetDir .. "/" .. name .. ".lua")
  local f = fs.open(targetDir .. "/" .. name .. ".lua", "w")
  if not f then error("Cannot write package file: " .. name) end
  f.write(data); f.close()
  if installedToGui then
    print("Installed " .. name .. " (gui)")
  else
    print("Installed " .. name)
  end
end

local function removeOne(name)
  if name == "nam" or name:lower() == "ninxstore" then
    print("Cannot remove protected package: " .. name)
    return
  end
  local removed = false
  local rootPath = PKG_DIR .. "/" .. name .. ".lua"
  local guiPath = GUI_DIR .. "/" .. name .. ".lua"
  if fs.exists(rootPath) then fs.delete(rootPath); print("Removed " .. name); removed = true end
  if fs.exists(guiPath) then fs.delete(guiPath); print("Removed " .. name .. " (gui)"); removed = true end
  if not removed then print("Not installed: " .. name) end
end

local function usage()
  print("nam - Ninx package manager (apt-like)")
  print("  -i <pkg> [pkg2...]   Install")
  print("  -r <pkg> [pkg2...]   Remove")
  print("  -s <query>           Search repo")
  print("  -l                   List repo packages")
  print("  -L                   List installed packages")
  print("  --repo               Show repo URL")
  print("  --set-repo <url>     Set repo URL")
end

local args = { ... }
if #args == 0 or args[1] == "-h" or args[1] == "--help" then usage(); return end
local flag = args[1]
if flag == "--repo" then
  print(readRepo()); return
elseif flag == "--set-repo" then
  local url = args[2]; if not url then print("Usage: nam --set-repo <url>"); return end
  local ok, err = writeRepo(url); if not ok then print("Error: " .. tostring(err)) end; return
elseif flag == "-L" then
  local list = listInstalled(); for _, n in ipairs(list) do print(n) end; return
elseif flag == "-l" then
  local index = fetchIndex();
  local names = {}
  for k in pairs(index) do table.insert(names, k) end
  table.sort(names);
  for _, n in ipairs(names) do print(n) end
  return
elseif flag == "-s" then
  local q = (args[2] or ""):lower()
  local index = fetchIndex()
  local matches = {}
  for name, info in pairs(index) do
    local desc = (info.description or ""):lower()
    if q == "" or name:lower():find(q, 1, true) or desc:find(q, 1, true) then
      table.insert(matches, name .. " - " .. (info.description or ""))
    end
  end
  table.sort(matches); for _, line in ipairs(matches) do print(line) end; return
elseif flag == "-i" then
  if not args[2] then print("Usage: nam -i <pkg> [pkg2...]"); return end
  local index = fetchIndex()
  for i = 2, #args do installOne(index, args[i]) end
  return
elseif flag == "-r" then
  if not args[2] then print("Usage: nam -r <pkg> [pkg2...]"); return end
  for i = 2, #args do removeOne(args[i]) end
  return
else
  usage(); return
end
