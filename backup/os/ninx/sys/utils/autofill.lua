
local fs = fs
local shell = shell
local table_unpack = table.unpack or unpack
local M = {}
local function scanDirPrograms(dir, seen)
  seen = seen or {}
  if not fs.exists(dir) or not fs.isDir(dir) then return seen end
  for _, entry in ipairs(fs.list(dir)) do
    local full = (dir:sub(-1) == "/") and (dir .. entry) or (dir .. "/" .. entry)
    if fs.isDir(full) then
      scanDirPrograms(full, seen)
    else
      local name = entry
      if name:sub(-4):lower() == ".lua" then name = name:sub(1, -5) end
      if name ~= "" and not seen[name:lower()] then
        seen[name:lower()] = name
      end
    end
  end
  return seen
end
local function loadCommands(commandsFile)
  if not fs.exists(commandsFile) then return {} end
  local ok, res = pcall(function() return dofile(commandsFile) end)
  if ok and type(res) == "table" then return res end
  return {}
end
local function listPackageNames(packagesDir)
  local out = {}
  if not fs.exists(packagesDir) then return out end
  for _,f in ipairs(fs.list(packagesDir)) do
    if f:sub(-4) == ".lua" then table.insert(out, f:sub(1, -5)) end
  end
  table.sort(out, function(a,b) return a:lower() < b:lower() end)
  return out
end
local function buildCandidates(packagesDir, commandsFile)
  local candMap = {}
  local builtinList = { "help", "list", "exit", "quit", "clear"}
  for _,b in ipairs(builtinList) do candMap[b:lower()] = b end
  local commands = loadCommands(commandsFile)
  for name,fn in pairs(commands) do
    if type(name) == "string" and type(fn) == "function" then
      candMap[name:lower()] = name
    end
  end
  for _,pkg in ipairs(listPackageNames(packagesDir)) do
    candMap[pkg:lower()] = pkg
  end
  local programDirs = {
    "/rom/programs", 
    "/rom/programs/turtle", "/rom/programs/pocket", "/rom/programs/computer",
    "/rom/programs/rednet", "/rom/programs/fun", "/rom/programs/gps", "/rom/programs/http",
    "/ninx/.sys/bin", "/ninx/.sys/utils/afex" 
  }
  for _,d in ipairs(programDirs) do
    if fs.exists(d) and fs.isDir(d) then
      local found = scanDirPrograms(d)
      for k,v in pairs(found) do candMap[k] = v end
    end
  end
  local candidates = {}
  for _,v in pairs(candMap) do table.insert(candidates, v) end
  table.sort(candidates, function(a,b) return a:lower() < b:lower() end)
  return candidates
end
function M.makeCompletion(packagesDir, commandsFile)
  packagesDir = packagesDir or "/ninx/packages"
  commandsFile = commandsFile or "/ninx/commands.lua"
  return function(text)
    local full = tostring(text or "")
    local prefix = full:match("^%s*(%S*)") or ""
    local lowPref = prefix:lower()
    local candidates = buildCandidates(packagesDir, commandsFile)
    local tokens = {}
    for w in full:gmatch("%S+") do table.insert(tokens, w) end
    local lastToken = ""
    local endsWithSpace = full:match("%s$") ~= nil
    if not endsWithSpace then lastToken = tokens[#tokens] or "" end
    local isFirstToken = (not endsWithSpace and #tokens <= 1) or (#tokens == 0)
    local function makeResult(list, typed)
      if #list == 0 then return {} end
      if #list == 1 then
        local c = list[1]
        local suffix = c:sub(#typed + 1)
        if suffix == "" then return {} end
        return { suffix }
      end
      return list
    end
    local function completePath(token)
      local dirPart, basePart = token:match("^(.*)/(.*)$")
      if not dirPart then dirPart = ""; basePart = token end
      local cwd = shell and shell.dir and shell.dir() or "."
      local absDir
      if dirPart == "" then
        absDir = cwd
      elseif dirPart:sub(1,1) == "/" then
        absDir = dirPart
      else
        absDir = (cwd ~= "/" and ("/"..cwd) or "") .. "/" .. dirPart
      end
      absDir = absDir:gsub("//+","/")
      local out = {}
      if fs.exists(absDir) and fs.isDir(absDir) then
        for _, entry in ipairs(fs.list(absDir)) do
          if entry:lower():sub(1, #basePart:lower()) == basePart:lower() then
            local fullEntry = (dirPart ~= "" and (dirPart .. "/" .. entry) or entry)
            local isDir = fs.isDir(absDir .. "/" .. entry)
            if isDir then fullEntry = fullEntry .. "/" end
            table.insert(out, fullEntry)
          end
        end
      end
      table.sort(out, function(a,b) return a:lower()<b:lower() end)
      return makeResult(out, token)
    end
    if isFirstToken then
      if lastToken == "" then return candidates end
      local matches = {}
      for _,c in ipairs(candidates) do
        if c:lower():sub(1, #lowPref) == lowPref then table.insert(matches, c) end
      end
      for _,c in ipairs(matches) do if c:lower() == lowPref then return {} end end
      return makeResult(matches, prefix)
    end
    return completePath(lastToken)
  end
end
return M