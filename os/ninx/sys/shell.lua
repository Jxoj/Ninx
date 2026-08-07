-- shell.lua  Ninx Shell v2.0
-- Linux-style prompt, folder-based packages, user context, fs permission sandbox

local fs, term, shell, textutils = fs, term, shell, textutils
_G.shell = shell; _G.fs = fs; _G.term = term; _G.textutils = textutils; _G.colors = colors

local PKG_DIR   = "/ninx/packages"
local BIN_DIR   = "/ninx/.sys/bin"
local LOG_DIR   = "/ninx/logs"
local unpack    = table.unpack or unpack

local function safeSetCursorBlink(v)
  if type(term)=="table" and type(term.setCursorBlink)=="function" then
    pcall(term.setCursorBlink, v)
  end
end

-- ─── Ensure dirs ──────────────────────────────────────────────────────────────
if not fs.exists(PKG_DIR) then fs.makeDir(PKG_DIR) end
if not fs.exists(LOG_DIR)  then fs.makeDir(LOG_DIR) end

-- ─── User/session helpers ─────────────────────────────────────────────────────
local function currentUser() return _G.NINX_USER or "guest" end
local function isRoot()      return _G.NINX_ROOT == true end
local function currentCwd()  return _G.NINX_CWD or "/" end
local function setCwd(p)     _G.NINX_CWD = p end

-- ─── Prompt string ────────────────────────────────────────────────────────────
local function makePrompt()
  local user = currentUser()
  local cwd  = currentCwd()
  local home = "/ninx/usr/" .. user .. "/home"
  -- Shorten home dir to ~
  if cwd == home then cwd = "~"
  elseif cwd:sub(1, #home) == home then cwd = "~" .. cwd:sub(#home+1)
  end
  local suffix = isRoot() and "#" or "$"
  return user .. "@ninx:" .. cwd .. suffix .. " "
end

-- ─── Permission sandbox (Global FS Hook) ───────────────────────────────────────
if not _G.fs._ninx_hooked then
  local origFs = {}
  for k,v in pairs(_G.fs) do origFs[k]=v end
  _G.fs._ninx_hooked = true
  _G.fs._orig = origFs

  local function checkWrite(dest)
    if _G.NINX_ROOT then return true end
    local usingSudo = _G.NINX_SUDO
    local ok, U = pcall(dofile, "/ninx/.sys/users.lua")
    if not ok then return true end
    if not U.mayWrite(dest, usingSudo) then
      error("No Permission: " .. tostring(dest), 3)
    end
    return true
  end

  _G.fs.open = function(p, mode, ...)
    if mode and (mode:sub(1,1)=="w" or mode:sub(1,1)=="a") then checkWrite(p) end
    return origFs.open(p, mode, ...)
  end
  _G.fs.delete = function(p) checkWrite(p); return origFs.delete(p) end
  _G.fs.move = function(s, d) checkWrite(s); checkWrite(d); return origFs.move(s,d) end
  _G.fs.copy = function(s, d) checkWrite(d); return origFs.copy(s,d) end
  _G.fs.makeDir = function(p) checkWrite(p); return origFs.makeDir(p) end
end

-- ─── Run helpers ──────────────────────────────────────────────────────────────
local function runBin(path, args)
  local ok, err = pcall(function()
    if args and #args>0 then shell.run(path, unpack(args)) else shell.run(path) end
  end)
  if not ok then
    term.setTextColor(colors.red); print("Error: " .. tostring(err)); term.setTextColor(colors.white)
  end
  return ok
end

-- Run a package (folder-based: main.lua) with sandbox
local function tryRunPackage(name, args)
  -- Folder-based package
  local dir  = PKG_DIR .. "/" .. name
  local main = dir .. "/main.lua"
  if fs.exists(main) then
    runBin(main, args)
    return true
  end
  -- Legacy: flat .lua in packages dir
  local flat = PKG_DIR .. "/" .. name .. ".lua"
  if fs.exists(flat) then
    runBin(flat, args)
    return true
  end
  return false
end

-- ─── Builtins ─────────────────────────────────────────────────────────────────
local function splitWords(s)
  local t={}; for w in s:gmatch("%S+") do t[#t+1]=w end; return t
end

local function printHelp()
  term.setTextColor(colors.orange); io.write("Ninx"); term.setTextColor(colors.white)
  print(" Shell v2.0")
  print("Builtins: help, clear, exit, cd <dir>, ls, pwd, ver")
  print("Commands in /ninx/.sys/bin: nam, usr, sudo, su, rootpwd, ...")
  print("Packages in /ninx/packages/<name>/main.lua - type the name to run")
end

local function doCD(args)
  local user = currentUser()
  local home = "/ninx/usr/" .. user .. "/home"
  local target = args[1]
  if not target or target == "~" then target = home end
  if target:sub(1,1) ~= "/" then
    target = (currentCwd():gsub("/$","")) .. "/" .. target
  end
  -- Normalise ..
  local parts = {}
  for p in target:gmatch("[^/]+") do
    if p == ".." then table.remove(parts)
    elseif p ~= "." then table.insert(parts, p) end
  end
  local resolved = "/" .. table.concat(parts, "/")
  if not fs.exists(resolved) then
    term.setTextColor(colors.red); print("cd: " .. resolved .. ": No such directory"); term.setTextColor(colors.white)
    return
  end
  if not fs.isDir(resolved) then
    term.setTextColor(colors.red); print("cd: " .. resolved .. ": Not a directory"); term.setTextColor(colors.white)
    return
  end
  setCwd(resolved)
end

local function doLS(args)
  local dir = args[1]
  if not dir then dir = currentCwd() end
  if dir:sub(1,1) ~= "/" then dir = currentCwd() .. "/" .. dir end
  if not fs.exists(dir) then
    term.setTextColor(colors.red); print("ls: cannot access '" .. dir .. "': No such file or directory")
    term.setTextColor(colors.white); return
  end
  local list = fs.list(dir)
  table.sort(list)
  local W = select(1, term.getSize())
  local maxLen = 0
  for _, f in ipairs(list) do if #f > maxLen then maxLen = #f end end
  local cols = math.max(1, math.floor(W / (maxLen + 2)))
  local i = 0
  for _, f in ipairs(list) do
    local full = dir:gsub("/$","") .. "/" .. f
    if fs.isDir(full) then term.setTextColor(colors.orange)
    else term.setTextColor(colors.white) end
    io.write(f .. string.rep(" ", maxLen + 2 - #f))
    i = i + 1
    if i % cols == 0 then print() end
  end
  if i % cols ~= 0 then print() end
  term.setTextColor(colors.white)
end

-- ─── Input: readline with autocomplete ────────────────────────────────────────
local completion = nil
do
  local ok, mod = pcall(dofile, "/ninx/.sys/utils/autofill.lua")
  if ok and type(mod)=="table" and type(mod.makeCompletion)=="function" then
    completion = mod.makeCompletion(PKG_DIR, BIN_DIR, currentCwd)
  else
    completion = function() return {} end
  end
end

local function readLine(promptStr, completionFn)
  io.write(promptStr)
  local buf = ""
  local baseX, baseY = term.getCursorPos()
  local prevHintLen = 0
  local W,H = term.getSize()

  local function redraw()
    local hint = ""
    if completionFn then
      local comp = completionFn(buf, currentCwd()) or {}
      if #comp == 1 then hint = comp[1]
      elseif #comp > 1 then
        local tok = buf:match("(%S+)%s*$") or ""
        local common = comp[1] or ""
        for i=2,#comp do
          local j=1; while j<=#common and j<=#comp[i] and common:sub(j,j)==comp[i]:sub(j,j) do j=j+1 end
          common = common:sub(1,j-1)
        end
        if #common > #tok then hint = common:sub(#tok+1) end
      end
    end
    -- Clear previous
    local prevTotal = (baseX-1) + #buf + prevHintLen
    local prevLines = math.ceil(prevTotal / W)
    for i=0, prevLines-1 do
      local y=baseY+i; local sc=(i==0) and baseX or 1
      term.setCursorPos(sc,y); term.setBackgroundColor(colors.black)
      term.write(string.rep(" ", W-sc+1))
    end
    -- Draw input
    local rem = #buf; local off = 1; local li = 0
    while rem > 0 do
      local sc = (li==0) and baseX or 1
      local sp = W-sc+1; local take = math.min(sp,rem)
      term.setCursorPos(sc, baseY+li)
      term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
      term.write(buf:sub(off,off+take-1))
      rem=rem-take; off=off+take; li=li+1
    end
    -- Draw hint
    if hint ~= "" then
      local tl = (baseX-1)+#buf; local hi_rem = #hint; local hi_off = 1
      local hi_line = math.floor(tl/W); local hi_x = (tl%W)+1
      while hi_rem > 0 do
        local sc=(hi_line==0) and hi_x or 1
        local sp=W-sc+1; local take=math.min(sp,hi_rem)
        term.setCursorPos(sc, baseY+hi_line)
        term.setBackgroundColor(colors.gray); term.setTextColor(colors.black)
        term.write(hint:sub(hi_off,hi_off+take-1))
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
        hi_rem=hi_rem-take; hi_off=hi_off+take; hi_line=hi_line+1
      end
    end
    -- Cursor position
    local tl = (baseX-1)+#buf
    local curY = baseY + math.floor(tl/W)
    local curX = (tl%W)+1
    if curY > H then
      local scroll = curY-H
      for _=1,scroll do term.scroll(1) end
      baseY=baseY-scroll; curY=H
    end
    term.setCursorPos(curX, curY)
    safeSetCursorBlink(true)
    prevHintLen = #hint
  end

  redraw()
  while true do
    local ev = {os.pullEvent()}
    if ev[1]=="char" then
      buf = buf .. ev[2]; redraw()
    elseif ev[1]=="key" then
      local k=ev[2]
      if k==keys.enter then
        local tl=(baseX-1)+#buf
        local cy=baseY+math.floor(tl/W); local cx=(tl%W)+1
        term.setCursorPos(cx,cy); print(); return buf
      elseif k==keys.backspace then
        if #buf>0 then buf=buf:sub(1,-2); redraw() end
      elseif k==keys.tab then
        if completionFn then
          local comp = completionFn(buf, currentCwd()) or {}
          if #comp==1 then
            buf=buf..comp[1]; redraw()
          elseif #comp>0 then
            local tok=buf:match("(%S+)%s*$") or ""
            local common=comp[1] or ""
            for i=2,#comp do
              local j=1; while j<=#common and j<=#comp[i] and common:sub(j,j)==comp[i]:sub(j,j) do j=j+1 end
              common=common:sub(1,j-1)
            end
            if #common>#tok then buf=buf..common:sub(#tok+1); redraw()
            else
              print()
              term.setTextColor(colors.gray); print(table.concat(comp,"  "))
              term.setTextColor(colors.white)
              io.write(promptStr); baseX,baseY=term.getCursorPos(); redraw()
            end
          end
        end
      end
    elseif ev[1]=="paste" and ev[2] then
      buf=buf..ev[2]; redraw()
    elseif ev[1]=="terminate" then
      error("Terminated")
    end
  end
end

-- ─── Main REPL ────────────────────────────────────────────────────────────────
local function repl()
  -- Welcome
  term.setTextColor(colors.orange); io.write("Ninx")
  term.setTextColor(colors.white); print(" Shell v2.0 - type 'help' for info")
  safeSetCursorBlink(true)

  while true do
    local prompt = makePrompt()
    term.setTextColor(isRoot() and colors.red or colors.orange)

    local ok, line = pcall(readLine, prompt, completion)
    term.setTextColor(colors.white)
    if not ok then print(); break end
    if not line then print(); break end

    line = line:gsub("^%s+",""):gsub("%s+$","")
    if line == "" then goto continue end

    local parts = splitWords(line)
    local cmd = parts[1]
    local args = {}
    for i=2,#parts do args[#args+1]=parts[i] end

    -- Builtins
    if cmd == "exit" or cmd == "quit" then
      print("Bye."); break

    elseif cmd == "help" then printHelp()
    elseif cmd == "clear" then term.clear(); term.setCursorPos(1,1)
    elseif cmd == "pwd"   then print(currentCwd())
    elseif cmd == "ver"   then
      local f=fs.open("/ninx/.sys/v","r")
      if f then local v=f.readAll();f.close(); print("Ninx v"..v)
      else print("Ninx (version unknown)") end

    elseif cmd == "cd" then doCD(args)
    elseif cmd == "ls" or cmd == "dir" then doLS(args)

    else
      local matched = false

      -- Check bin/ commands
      local binPath = BIN_DIR .. "/" .. cmd .. ".lua"
      if fs.exists(binPath) then
        runBin(binPath, args); matched = true

      -- Check packages (folder-based, then flat)
      elseif tryRunPackage(cmd, args) then
        matched = true

      -- Try full path
      elseif cmd:find("/") then
        if fs.exists(cmd) then
          if fs.isDir(cmd) then
            doCD({cmd}); matched = true
          else
            runBin(cmd, args); matched = true
          end
        else
          term.setTextColor(colors.red); print("File not found: "..cmd); term.setTextColor(colors.white)
          matched = true
        end

      -- Fall back to CraftOS shell
      else
        local okC, errC = pcall(function()
          if #args>0 then shell.run(cmd, unpack(args)) else shell.run(cmd) end
        end)
        if not okC then
          term.setTextColor(colors.red); print("Command not found: "..cmd); term.setTextColor(colors.white)
        end
        matched = true
      end
      _ = matched
    end

    ::continue::
  end
end

-- ─── Entry ────────────────────────────────────────────────────────────────────
local initArgs = {...}
-- Set working directory to user home if not already set
if not _G.NINX_CWD then
  _G.NINX_CWD = "/ninx/usr/" .. currentUser() .. "/home"
  if not fs.exists(_G.NINX_CWD) then fs.makeDir(_G.NINX_CWD) end
end

if initArgs and #initArgs>0 and initArgs[1]~="" then
  local prog = initArgs[1]
  local pArgs = {}
  for i=2,#initArgs do pArgs[#pArgs+1]=initArgs[i] end
  local ok, err = pcall(function()
    runBin(prog, pArgs)
  end)
  if not ok then
    term.setTextColor(colors.red); print("Error: "..tostring(err)); term.setTextColor(colors.white)
  end
end

repl()