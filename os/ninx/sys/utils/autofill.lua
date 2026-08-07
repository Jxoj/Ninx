-- autofill.lua  Ninx shell autocomplete v2.0
-- Supports: command names, package names, bin commands, file/path args

local fs    = fs
local M     = {}

local function isDir(p)
  return fs.exists(p) and fs.isDir(p)
end

-- Scan dir for programs recursively
local function scanPrograms(dir, seen)
  seen = seen or {}
  if not isDir(dir) then return seen end
  local ok, list = pcall(fs.list, dir)
  if not ok then return seen end
  for _, entry in ipairs(list) do
    local full = dir .. "/" .. entry
    if isDir(full) then
      scanPrograms(full, seen)
    else
      local name = entry
      if name:sub(-4):lower() == ".lua" then name = name:sub(1,-5) end
      if name ~= "" and not seen[name:lower()] then seen[name:lower()] = name end
    end
  end
  return seen
end

-- Scan packages dir for folder-based packages (look for main.lua inside)
local function scanPackages(pkgDir, seen)
  seen = seen or {}
  if not isDir(pkgDir) then return seen end
  local ok, list = pcall(fs.list, pkgDir)
  if not ok then return seen end
  for _, entry in ipairs(list) do
    local full = pkgDir .. "/" .. entry
    if isDir(full) then
      if fs.exists(full .. "/main.lua") then
        if not seen[entry:lower()] then seen[entry:lower()] = entry end
      end
    elseif entry:sub(-4) == ".lua" then
      local name = entry:sub(1,-5)
      if not seen[name:lower()] then seen[name:lower()] = name end
    end
  end
  return seen
end

local BUILTINS = {"help","clear","exit","quit","cd","ls","dir","pwd","ver","nano","edit"}

local function buildCandidates(pkgDir, binDir)
  local candMap = {}
  for _, b in ipairs(BUILTINS) do candMap[b:lower()] = b end

  -- Bin commands
  local binSeen = scanPrograms(binDir or "/ninx/.sys/bin", {})
  for k,v in pairs(binSeen) do candMap[k] = v end

  -- Package names
  local pkgSeen = scanPackages(pkgDir or "/ninx/packages", {})
  for k,v in pairs(pkgSeen) do candMap[k] = v end

  -- ROM programs
  local romDirs = {
    "/rom/programs", "/rom/programs/computer", "/rom/programs/http",
    "/rom/programs/fun", "/rom/programs/rednet", "/rom/programs/turtle",
  }
  for _, d in ipairs(romDirs) do
    local s = scanPrograms(d, {})
    for k,v in pairs(s) do candMap[k] = v end
  end

  local out = {}
  for _, v in pairs(candMap) do out[#out+1] = v end
  table.sort(out, function(a,b) return a:lower() < b:lower() end)
  return out
end

-- File/directory completion relative to cwd
local function completePath(token, getCwd)
  local cwd = (type(getCwd)=="function" and getCwd()) or "/"
  cwd = cwd:gsub("/$","")

  local dirPart, basePart = token:match("^(.*)/(.*)$")
  if not dirPart then dirPart = ""; basePart = token end

  local absDir
  if dirPart == "" then
    absDir = cwd
  elseif dirPart == "~" then
    local user = _G.NINX_USER or "guest"
    absDir = "/ninx/usr/" .. user .. "/home"
  elseif dirPart:sub(1,1) == "/" then
    absDir = dirPart
  else
    absDir = cwd .. "/" .. dirPart
  end
  absDir = absDir:gsub("//+","/")

  if not isDir(absDir) then return {} end
  local ok, entries = pcall(fs.list, absDir)
  if not ok then return {} end

  local out = {}
  local lowBase = basePart:lower()
  for _, e in ipairs(entries) do
    if e:lower():sub(1,#lowBase) == lowBase then
      local suffix = e:sub(#basePart+1)
      local fullEntry = (dirPart ~= "" and (dirPart.."/"..e)) or e
      local isD = isDir(absDir.."/"..e)
      table.insert(out, isD and (fullEntry.."/") or fullEntry)
    end
  end
  table.sort(out, function(a,b) return a:lower()<b:lower() end)

  -- Return as suffixes
  local result = {}
  for _, e in ipairs(out) do
    result[#result+1] = e:sub(#token+1)
  end
  return result
end

function M.makeCompletion(pkgDir, binDir, getCwd)
  local candidates = nil

  return function(text, cwd)
    -- Lazy-load candidates
    if not candidates then
      candidates = buildCandidates(pkgDir, binDir)
    end

    local full  = tostring(text or "")
    local tokens = {}
    for w in full:gmatch("%S+") do tokens[#tokens+1] = w end
    local endsSpace = full:match("%s$") ~= nil
    local lastTok   = (not endsSpace and tokens[#tokens]) or ""
    local isFirst   = (not endsSpace and #tokens <= 1)

    if isFirst then
      -- Complete command name
      if lastTok == "" then return candidates end
      local low = lastTok:lower()
      local matches = {}
      for _, c in ipairs(candidates) do
        if c:lower():sub(1,#low) == low then
          matches[#matches+1] = c
        end
      end
      -- Return as suffixes
      local result = {}
      for _, m in ipairs(matches) do
        local suf = m:sub(#lastTok+1)
        if suf ~= "" then result[#result+1] = suf end
      end
      if #result == 0 and #matches == 1 and matches[1]:lower() == low then
        return {}
      end
      return #result > 0 and result or matches
    else
      -- Complete file path for subsequent args
      return completePath(lastTok, getCwd)
    end
  end
end

return M