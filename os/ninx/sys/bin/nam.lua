-- nam.lua  Ninx Application Manager v2.0
-- Full rewrite: zip-based packages, multiple repos, versioned metadata, user system
--
-- Package JSON format (repo):
--   [ { "id":"helloworld", "name":"Hello World", "author":"Jxoj",
--       "version":"1.0.0", "description":"...", "zip":"<url>" }, ... ]
--
-- Installed metadata: /ninx/packages/(id)/com.(author).(id).json
--
-- All installs require sudo. nam update checks versions.

local PKG_DIR     = "/ninx/packages"
local CFG_DIR     = "/ninx/.sys/config"
local REPOS_FILE  = "/ninx/.sys/config/nam.cfg"
local DEFAULT_REPO = "https://raw.githubusercontent.com/Jxoj/Ninx-Pkgs/main/pkgs.json"

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function ensureDir(path)
  if path and path ~= "" and not fs.exists(path) then fs.makeDir(path) end
end

local function col(c, text)
  term.setTextColor(c); io.write(text); term.setTextColor(colors.white)
end
local function println(text, c) term.setTextColor(c or colors.white); print(text or ""); term.setTextColor(colors.white) end
local function status(tag, c, msg) col(colors.white,"["); col(c,tag); col(colors.white,"] "); println(msg) end

-- ─── Permission check ────────────────────────────────────────────────────────
local function requireSudo()
  if not (_G.NINX_SUDO or _G.NINX_ROOT) then
    println("Error: this operation requires sudo. Run: sudo nam ...", colors.red)
    return false
  end
  return true
end

-- ─── Repo management ─────────────────────────────────────────────────────────
local function readRepos()
  ensureDir(CFG_DIR)
  if not fs.exists(REPOS_FILE) then
    local f = fs.open(REPOS_FILE,"w"); if f then f.write(DEFAULT_REPO.."\n"); f.close() end
  end
  local repos = {}
  local f = fs.open(REPOS_FILE,"r"); if not f then return {DEFAULT_REPO} end
  while true do
    local l = f.readLine(); if not l then break end
    l = l:match("^%s*(.-)%s*$")
    if l ~= "" then table.insert(repos, l) end
  end
  f.close()
  if #repos == 0 then repos = {DEFAULT_REPO} end
  return repos
end

local function writeRepos(repos)
  ensureDir(CFG_DIR)
  local f = fs.open(REPOS_FILE,"w"); if not f then return false end
  for _, r in ipairs(repos) do f.writeLine(r) end
  f.close(); return true
end

-- ─── Network helpers ─────────────────────────────────────────────────────────
local function httpGet(url, binary)
  if not http then error("HTTP API disabled. Enable HTTP in ComputerCraft config.") end
  local res = http.get(url, {}, binary or false)
  if not res then error("Failed to fetch: " .. url) end
  local data = res.readAll(); res.close()
  return data
end

local function fetchIndex()
  local repos = readRepos()
  local combined = {}
  for _, url in ipairs(repos) do
    local ok, data = pcall(httpGet, url)
    if ok and data then
      local ok2, parsed = pcall(textutils.unserializeJSON, data)
      if ok2 and type(parsed) == "table" then
        for _, pkg in ipairs(parsed) do
          if pkg.id then combined[pkg.id] = pkg end
        end
      else
        status("Warn", colors.orange, "Invalid JSON from repo: " .. url)
      end
    else
      status("Warn", colors.orange, "Could not reach repo: " .. url)
    end
  end
  return combined
end

-- ─── Version comparison ───────────────────────────────────────────────────────
-- Returns -1,0,1 for a<b, a==b, a>b. Handles "1.2.3" format.
local function verCompare(a, b)
  a = tostring(a or "0"); b = tostring(b or "0")
  local function parts(v)
    local t={}; for n in v:gmatch("%d+") do table.insert(t,tonumber(n) or 0) end
    return t
  end
  local ap, bp = parts(a), parts(b)
  local len = math.max(#ap, #bp)
  for i=1,len do
    local av = ap[i] or 0; local bv = bp[i] or 0
    if av < bv then return -1 end
    if av > bv then return  1 end
  end
  return 0
end

-- ─── Package metadata I/O ────────────────────────────────────────────────────
local function metaPath(pkgDir, author, id)
  return pkgDir .. "/com." .. author .. "." .. id .. ".json"
end

local function readMeta(id)
  local pkgDir = PKG_DIR .. "/" .. id
  if not fs.exists(pkgDir) then return nil end
  -- scan for com.*.*.json
  for _, f in ipairs(fs.list(pkgDir)) do
    if f:match("^com%.") and f:sub(-5) == ".json" then
      local fh = fs.open(pkgDir.."/"..f,"r")
      if fh then
        local raw=fh.readAll(); fh.close()
        local ok,t=pcall(textutils.unserializeJSON,raw)
        if ok and t then return t end
      end
    end
  end
  return nil
end

local function writeMeta(id, author, version, name)
  local pkgDir = PKG_DIR .. "/" .. id
  ensureDir(pkgDir)
  local path = metaPath(pkgDir, author, id)
  local t = { id=id, name=name or id, author=author, version=version }
  local fh = fs.open(path,"w"); if not fh then return false end
  fh.write(textutils.serializeJSON(t)); fh.close(); return true
end

-- ─── Install / Remove ────────────────────────────────────────────────────────
local function isInstalled(id)
  local pkgDir = PKG_DIR .. "/" .. id
  return fs.exists(pkgDir) and fs.exists(pkgDir .. "/main.lua")
end

local function installPkg(info)
  if not requireSudo() then return false end
  local id      = info.id
  local author  = info.author  or "unknown"
  local version = info.version or "0.0.0"
  local zipUrl  = info.zip
  if not zipUrl then
    println("Package '" .. id .. "' has no zip URL.", colors.red); return false
  end

  status("Info", colors.yellow, "Downloading " .. id .. " v" .. version .. "...")
  local ok, zipData = pcall(httpGet, zipUrl, true)
  if not ok then
    status("Error", colors.red, "Download failed: " .. tostring(zipData)); return false
  end

  local pkgDir = PKG_DIR .. "/" .. id
  ensureDir(pkgDir)

  -- Extract ZIP
  local zipLib = dofile("/ninx/.sys/utils/zip.lua")
  local ok2, result = zipLib.extract(zipData, pkgDir)
  if not ok2 then
    status("Error", colors.red, "Extraction failed: " .. tostring(result)); return false
  end

  -- Write metadata
  writeMeta(id, author, version, info.name)

  status("Success", colors.green, "Installed " .. id .. " v" .. version)
  return true
end

local function removePkg(id)
  if not requireSudo() then return false end
  local pkgDir = PKG_DIR .. "/" .. id
  if not fs.exists(pkgDir) then
    println("Not installed: " .. id, colors.orange); return false
  end
  fs.delete(pkgDir)
  status("Success", colors.green, "Removed " .. id)
  return true
end

-- ─── Update ──────────────────────────────────────────────────────────────────
local function updateAll()
  if not requireSudo() then return end
  status("Info", colors.yellow, "Fetching package index...")
  local index = fetchIndex()
  if not fs.exists(PKG_DIR) then println("No packages installed.", colors.orange); return end

  local updated = 0
  for _, dir in ipairs(fs.list(PKG_DIR)) do
    local full = PKG_DIR .. "/" .. dir
    if fs.isDir(full) then
      local meta = readMeta(dir)
      if meta and meta.id and index[meta.id] then
        local remote = index[meta.id]
        if verCompare(meta.version, remote.version) < 0 then
          status("Info", colors.yellow, "Updating " .. dir .. ": " .. meta.version .. " -> " .. remote.version)
          removePkg(dir)
          installPkg(remote)
          updated = updated + 1
        end
      end
    end
  end
  if updated == 0 then
    status("Success", colors.green, "All packages are up to date.")
  else
    status("Success", colors.green, updated .. " package(s) updated.")
  end
end

-- ─── List / Search ───────────────────────────────────────────────────────────
local function listInstalled()
  if not fs.exists(PKG_DIR) then println("No packages installed."); return end
  local found = false
  for _, dir in ipairs(fs.list(PKG_DIR)) do
    local full = PKG_DIR .. "/" .. dir
    if fs.isDir(full) and fs.exists(full .. "/main.lua") then
      found = true
      local meta = readMeta(dir)
      local ver  = meta and meta.version or "?"
      local auth = meta and meta.author  or "?"
      col(colors.orange, dir); col(colors.gray, "  v"..ver.."  by "..auth); print()
    end
  end
  if not found then println("No packages installed.") end
end

local function listRemote()
  status("Info", colors.yellow, "Fetching package index...")
  local index = fetchIndex()
  local names = {}
  for k in pairs(index) do table.insert(names, k) end
  table.sort(names)
  for _, n in ipairs(names) do
    local p = index[n]
    col(colors.orange, n)
    col(colors.gray, "  v"..(p.version or "?").."  by "..(p.author or "?"))
    col(colors.white, "  "..(p.description or ""))
    print()
  end
end

local function searchPkgs(query)
  status("Info", colors.yellow, "Searching...")
  local index = fetchIndex()
  query = query:lower()
  local found = false
  for id, p in pairs(index) do
    local match = id:lower():find(query,1,true)
        or (p.name or ""):lower():find(query,1,true)
        or (p.description or ""):lower():find(query,1,true)
    if match then
      found = true
      col(colors.orange, id)
      col(colors.gray,   "  v"..(p.version or "?").."  by "..(p.author or "?"))
      col(colors.white,  "  "..(p.description or ""))
      print()
    end
  end
  if not found then println("No packages match: " .. query) end
end

-- ─── Usage ────────────────────────────────────────────────────────────────────
local function usage()
  col(colors.orange, "nam"); println(" — Ninx Application Manager v2.0")
  println("  install <pkg> [pkg2...]   Install packages (requires sudo)")
  println("  remove  <pkg> [pkg2...]   Remove packages (requires sudo)")
  println("  update                    Check and update all installed packages (requires sudo)")
  println("  list                      List installed packages")
  println("  search  <query>           Search repositories")
  println("  remote                    List all available packages")
  println("  repo list                 List configured repositories")
  println("  repo add <url>            Add a repository")
  println("  repo remove <url>         Remove a repository")
  println("  repo reset                Reset to default repository")
end

-- ─── Entry point ─────────────────────────────────────────────────────────────
local args = {...}
if #args == 0 then usage(); return end

local cmd = args[1]

if cmd == "install" or cmd == "-i" then
  if not args[2] then println("Usage: nam install <pkg> [pkg2...]", colors.red); return end
  status("Info", colors.yellow, "Fetching package index...")
  local index = fetchIndex()
  for i = 2, #args do
    local id = args[i]
    if isInstalled(id) then
      status("Info", colors.orange, id .. " is already installed")
    elseif index[id] then
      installPkg(index[id])
    else
      status("Error", colors.red, "Package not found: " .. id)
    end
  end

elseif cmd == "remove" or cmd == "-r" then
  if not args[2] then println("Usage: nam remove <pkg>", colors.red); return end
  for i = 2, #args do removePkg(args[i]) end

elseif cmd == "update" then
  updateAll()

elseif cmd == "list" or cmd == "-L" then
  listInstalled()

elseif cmd == "remote" or cmd == "-l" then
  listRemote()

elseif cmd == "search" or cmd == "-s" then
  if not args[2] then println("Usage: nam search <query>", colors.red); return end
  searchPkgs(args[2])

elseif cmd == "repo" then
  local sub = args[2]
  if sub == "list" then
    local repos = readRepos()
    for i, r in ipairs(repos) do println(i .. ". " .. r) end
  elseif sub == "add" then
    if not args[3] then println("Usage: nam repo add <url>", colors.red); return end
    local repos = readRepos()
    for _, r in ipairs(repos) do
      if r == args[3] then println("Repo already added.", colors.orange); return end
    end
    table.insert(repos, args[3])
    writeRepos(repos)
    status("Success", colors.green, "Added repo: " .. args[3])
  elseif sub == "remove" then
    if not args[3] then println("Usage: nam repo remove <url>", colors.red); return end
    local repos = readRepos()
    local newRepos = {}
    local found = false
    for _, r in ipairs(repos) do
      if r == args[3] then found = true else table.insert(newRepos, r) end
    end
    if found then writeRepos(newRepos); status("Success", colors.green, "Removed repo.")
    else println("Repo not found.", colors.orange) end
  elseif sub == "reset" then
    writeRepos({DEFAULT_REPO})
    status("Success", colors.green, "Repos reset to default.")
  else
    println("Usage: nam repo [list|add|remove|reset]", colors.red)
  end

else
  println("Unknown command: " .. cmd, colors.red)
  usage()
end
