






local fs, term, shell, textutils = fs, term, shell, textutils
_G.shell = shell
_G.fs = fs
_G.term = term
_G.textutils = textutils
_G.colors = colors
local PACKAGES_DIR = "/ninx/packages"
local GUI_PACKAGES_DIR = PACKAGES_DIR .. "/gui"
local BIN_DIR = "/ninx/.sys/bin"       
local GBIN_DIR = "/ninx/.sys/gbin"     
local COMMANDS_FILE = "/ninx/commands.lua"
local LOG_DIR = "/ninx/logs"
local unpack = table.unpack or unpack


local DEBUG_RUNMODE = true
local initArgs = { ... }

local function safeSetCursorBlink(v)
  if type(term) == "table" and type(term.setCursorBlink) == "function" then
    pcall(term.setCursorBlink, v)
  end
end

if not fs.exists(PACKAGES_DIR) then fs.makeDir(PACKAGES_DIR) end
if not fs.exists(LOG_DIR) then fs.makeDir(LOG_DIR) end

if not fs.exists(COMMANDS_FILE) then
  local ok, h = pcall(function() return fs.open(COMMANDS_FILE, "w") end)
  if ok and h then
    h.write([[

local commands = {}
commands.about = function(args)
  term.setTextColor(colors.white)
  io.write("")
  term.setTextColor(colors.purple)
  io.write("Ninx")
  term.setTextColor(colors.white)
  print(" Shell 1.0")
end
return commands
]])
    h.close()
  end
end

local completion = nil
do
  local ok, mod = pcall(function() return dofile("/ninx/.sys/utils/autofill.lua") end)
  if ok and type(mod) == "table" and type(mod.makeCompletion) == "function" then
    completion = mod.makeCompletion(PACKAGES_DIR, COMMANDS_FILE)
  else
    completion = function() return {} end
    term.setTextColor(colors.red)
    print("Warning: autofill module failed to load; completions disabled.")
    term.setTextColor(colors.white)
  end
end

local function splitWords(s)
  local t = {}
  for w in s:gmatch("%S+") do table.insert(t, w) end
  return t
end
local function sanitizeName(name)
  if not name or type(name) ~= "string" then return nil end
  if name:find("[/\\]") or name:find("%.%.") then return nil end
  if name:sub(-4) == ".lua" then name = name:sub(1, -5) end
  if name == "" then return nil end
  return name
end
local function ensureSlash(p)
  if type(p) ~= "string" then return p end
  if p:sub(-1) ~= "/" then return p .. "/" end
  return p
end
local function isPathInDir(path, dir)
  if type(path) ~= "string" or type(dir) ~= "string" then return false end
  local nd = ensureSlash(dir)
  local np = path
  if np:sub(-1) == "/" then np = np:sub(1, -2) end
  return np:sub(1, #nd) == nd
end

local function runOnTop(path, args)
  if DEBUG_RUNMODE then
    term.setTextColor(colors.lightBlue)
    print("Starting (ON-TOP): " .. tostring(path))
    term.setTextColor(colors.white)
  end
  local ok, err = pcall(function()
    if args and #args > 0 then shell.run(path, unpack(args)) else shell.run(path) end
  end)
  if ok then
    if DEBUG_RUNMODE then
      term.setTextColor(colors.lightBlue)
      print("Finished (ON-TOP): " .. tostring(path))
      term.setTextColor(colors.white)
    end
  else
    term.setTextColor(colors.red)
    print("Error while running (ON-TOP): " .. tostring(err))
    term.setTextColor(colors.white)
  end
  
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1,1)
  term.setTextColor(colors.white)
  safeSetCursorBlink(true)
  return ok, err
end

local function runNormally(path, args)
  if DEBUG_RUNMODE then
    term.setTextColor(colors.green)
    print("Starting (NORMAL): " .. tostring(path))
    term.setTextColor(colors.white)
  end
  local ok, err = pcall(function()
    if args and #args > 0 then shell.run(path, unpack(args)) else shell.run(path) end
  end)
  if ok then
    if DEBUG_RUNMODE then
      term.setTextColor(colors.green)
      print("Finished (NORMAL): " .. tostring(path))
      term.setTextColor(colors.white)
    end
  else
    term.setTextColor(colors.red)
    print("Error while running (NORMAL): " .. tostring(err))
    term.setTextColor(colors.white)
  end
  
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1,1)
  term.setTextColor(colors.white)
  safeSetCursorBlink(true)
  return ok, err
end



local function runBinSilent(path, args)
  local ok, err = pcall(function()
    if args and #args > 0 then shell.run(path, unpack(args)) else shell.run(path) end
  end)
  if not ok then
    term.setTextColor(colors.red)
    print("Error in bin:", tostring(err))
    term.setTextColor(colors.white)
  end
  
  safeSetCursorBlink(true)
  return ok, err
end
local function candidates(dir, name)
  return {
    dir .. "/" .. name .. ".lua",
    dir .. "/" .. name:lower() .. ".lua",
    dir .. "/" .. name:upper() .. ".lua",
  }
end



local function tryRunPackageByName(name, args)
  if not name then return false end
  
  if fs.exists(GUI_PACKAGES_DIR) then
    for _, path in ipairs(candidates(GUI_PACKAGES_DIR, name)) do
      if fs.exists(path) and isPathInDir(path, GUI_PACKAGES_DIR) then
        runOnTop(path, args)
        return true
      end
    end
  end
  
  if fs.exists(PACKAGES_DIR) then
    for _, path in ipairs(candidates(PACKAGES_DIR, name)) do
      if fs.exists(path) and not isPathInDir(path, GUI_PACKAGES_DIR) then
        runNormally(path, args)
        return true
      end
    end
  end
  return false
end
local function listPackages()
  term.setTextColor(colors.white)
  if not fs.exists(PACKAGES_DIR) then print("(no packages found in " .. PACKAGES_DIR .. ")") return end
  for _,f in ipairs(fs.list(PACKAGES_DIR)) do
    if f:sub(-4) == ".lua" then print(f:sub(1, -5)) end
  end
end
local function printHelp()
  term.setTextColor(colors.white)
  io.write("")
  term.setTextColor(colors.purple)
  io.write("Ninx")
  term.setTextColor(colors.white)
  print(" Shell 1.0 - help")
  print("Commands: help, list, exit, quit, clear")
  local ok, commands = pcall(function() return dofile(COMMANDS_FILE) end)
  local cmds = {}
  if ok and type(commands) == "table" then
    for name,fn in pairs(commands) do
      if type(name) == "string" and type(fn) == "function" then table.insert(cmds, name) end
    end
  end
  if #cmds > 0 then
    table.sort(cmds, function(a,b) return a:lower() < b:lower() end)
    io.write("")
    for i,name in ipairs(cmds) do
      io.write(name)
      if i < #cmds then io.write(", ") end
    end
    print()
  end
  print(" To run a package, type its name.")
end

local function repl()
  term.setTextColor(colors.white)
  io.write("Welcome to ")
  term.setTextColor(colors.purple)
  io.write("Ninx")
  term.setTextColor(colors.white)
  print(" Shell 1.0 - type 'help' for more info.")
  
  safeSetCursorBlink(true)
  local function readWithIdle(idleSeconds, completionFn)
    local buf = ""
    local prevLen = 0
    local baseX, baseY = term.getCursorPos()
    local currentTimer = os.startTimer(idleSeconds)
    local keysTbl = keys
    local prevHintLen = 0
    local function redraw()
      local w, h = term.getSize()
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.white)
      local hint = ""
      if completionFn then
        local comp = completionFn(buf) or {}
        if #comp == 1 and type(comp[1]) == "string" and not comp[2] then
          hint = comp[1]
        elseif #comp > 1 then
          local token = buf:match("(%S+)$") or ""
          local function common_prefix(a,b)
            local i = 1
            while i <= #a and i <= #b and a:sub(i,i):lower() == b:sub(i,i):lower() do i = i + 1 end
            return a:sub(1, i-1)
          end
          local common = comp[1] or ""
          for i=2,#comp do common = common_prefix(common, comp[i] or "") end
          if #common > #token then hint = common:sub(#token + 1) end
        end
      end
      local prevDrawnLen = prevLen + prevHintLen
      if prevDrawnLen > 0 then
        local prevTotal = (baseX - 1) + prevDrawnLen
        local prevLines = math.floor((prevTotal + w - 1) / w)
        term.setBackgroundColor(colors.black)
        for i = 0, prevLines - 1 do
          local y = baseY + i
          local startCol = (i == 0) and baseX or 1
          local clearLen = w - startCol + 1
          term.setCursorPos(startCol, y)
          term.write(string.rep(" ", clearLen))
        end
      end
      local remaining = #buf
      local offset = 1
      local lineIndex = 0
      while remaining > 0 do
        local startCol = (lineIndex == 0) and baseX or 1
        local spaceLeft = w - startCol + 1
        local take = math.min(spaceLeft, remaining)
        term.setCursorPos(startCol, baseY + lineIndex)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.write(string.sub(buf, offset, offset + take - 1))
        remaining = remaining - take
        offset = offset + take
        lineIndex = lineIndex + 1
      end
      if hint ~= "" then
        local totalLenSoFar = (baseX - 1) + #buf
        local hintRem = #hint
        local hintOff = 1
        local lineIdx = math.floor(totalLenSoFar / w)
        local startX = (totalLenSoFar % w) + 1
        while hintRem > 0 do
          local startCol = (lineIdx == 0) and startX or 1
          local spaceLeft = w - startCol + 1
          local take = math.min(spaceLeft, hintRem)
          term.setCursorPos(startCol, baseY + lineIdx)
          term.setBackgroundColor(colors.lightGray)
          term.setTextColor(colors.black)
          term.write(string.sub(hint, hintOff, hintOff + take - 1))
          term.setBackgroundColor(colors.black)
          term.setTextColor(colors.white)
          hintRem = hintRem - take
          hintOff = hintOff + take
          lineIdx = lineIdx + 1
        end
      end
      local totalLen = (baseX - 1) + #buf
      local cursorY = baseY + math.floor(totalLen / w)
      local cursorX = (totalLen % w) + 1
      if cursorY > h then
        local scrollAmount = cursorY - h
        for i = 1, scrollAmount do term.scroll(1) end
        baseY = baseY - scrollAmount
        cursorY = h
      end
      term.setCursorPos(cursorX, cursorY)
      
      safeSetCursorBlink(true)
      prevHintLen = #hint
      prevLen = #buf
    end
    redraw()
    while true do
      local ev = { os.pullEvent() }
      if ev[1] == "char" then
        buf = buf .. tostring(ev[2] or "")
        redraw()
        currentTimer = os.startTimer(idleSeconds)
      elseif ev[1] == "key" then
        local k = ev[2]
        if k == keys.enter then
          local termWidth = select(1, term.getSize())
          local totalLen = baseX - 1 + #buf
          local cursorY = baseY + math.floor(totalLen / termWidth)
          local cursorX = (totalLen % termWidth) + 1
          term.setCursorPos(cursorX, cursorY)
          safeSetCursorBlink(true)
          print()
          return buf
        elseif k == keys.backspace then
          if #buf > 0 then
            buf = buf:sub(1, -2)
            redraw()
          end
          currentTimer = os.startTimer(idleSeconds)
        elseif k == keys.tab then
          if completionFn then
            local comp = completionFn(buf) or {}
            if #comp == 1 and type(comp[1]) == "string" then
              buf = buf .. comp[1]
              redraw()
            else
              local token = buf:match("(%S+)$") or ""
              local function common_prefix(a,b)
                local i=1; while i<=#a and i<=#b and a:sub(i,i):lower()==b:sub(i,i):lower() do i=i+1 end; return a:sub(1,i-1) end
              local common = comp[1] or ""
              for i=2,#comp do common = common_prefix(common, comp[i] or "") end
              if common ~= "" and #common > #token then
                buf = buf .. common:sub(#token+1)
                redraw()
              elseif #comp > 0 then
                print()
                term.setTextColor(colors.white)
                local joined = table.concat(comp, ", ")
                print(joined)
                term.setTextColor(colors.purple)
                local computerName = os.getComputerLabel() or ("Computer" .. os.getComputerID())
                term.write("[" .. computerName .. "] > ")
                baseX, baseY = term.getCursorPos()
                redraw()
              end
            end
          end
          currentTimer = os.startTimer(idleSeconds)
        elseif k == keys.left or k == keys.right or k == keys.up or k == keys.down then
          currentTimer = os.startTimer(idleSeconds)
        elseif k == keys.delete then
          if #buf > 0 then
            buf = buf:sub(1, -2)
            redraw()
          end
          currentTimer = os.startTimer(idleSeconds)
        else
          currentTimer = os.startTimer(idleSeconds)
        end
      elseif ev[1] == "paste" then
        if ev[2] and type(ev[2]) == "string" then
          buf = buf .. ev[2]
          redraw()
        end
        currentTimer = os.startTimer(idleSeconds)
      elseif ev[1] == "mouse_click" or ev[1] == "mouse_up" or ev[1] == "mouse_drag" then
        currentTimer = os.startTimer(idleSeconds)
      elseif ev[1] == "timer" then
        if ev[2] == currentTimer then
          term.setTextColor(colors.white)
          local scPath = "/ninx/.sys/desktop/screensaver.lua"
          if fs.exists(scPath) then
            local okS, errS = pcall(function() shell.run(scPath) end)
            if not okS then
              term.setTextColor(colors.red)
              print("Error running screensaver:", tostring(errS))
              term.setTextColor(colors.white)
            end
          end
          term.setTextColor(colors.purple)
          local computerName = os.getComputerLabel() or ("Computer" .. os.getComputerID())
          term.write("[" .. computerName .. "] > ")
          baseX, baseY = term.getCursorPos()
          redraw()
          currentTimer = os.startTimer(idleSeconds)
        end
      elseif ev[1] == "terminate" then
        error("Terminated")
      else
        currentTimer = os.startTimer(idleSeconds)
      end
    end
  end
  while true do
    term.setTextColor(colors.purple)
    local computerName = os.getComputerLabel() or ("Computer" .. os.getComputerID())
    term.write("[" .. computerName .. "] > ")
    term.setTextColor(colors.purple)
    
    safeSetCursorBlink(true)
    local ok, line = pcall(function() return readWithIdle(60, completion) end)
    term.setTextColor(colors.white)
    if not ok then print() break end
    if not line then print() break end
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" then
      local parts = splitWords(line)
      local cmd = parts[1]
      local args = {}
      for i=2,#parts do args[#args+1] = parts[i] end
      if cmd == "help" then
        printHelp()
      elseif cmd == "list" then
        listPackages()
      elseif cmd == "exit" or cmd == "quit" then
        print("Bye.")
        break
      elseif cmd == "clear" then
        term.clear()
        term.setCursorPos(1,1)
      else
        local commands = {}
        local okc, res = pcall(function() return dofile(COMMANDS_FILE) end)
        if okc and type(res) == "table" then commands = res end
        local matched = false
        local lowerCmd = cmd:lower()
        for name,fn in pairs(commands) do
          if type(name) == "string" and type(fn) == "function" and name:lower() == lowerCmd then
            local ok2, err = pcall(function() fn(args) end)
            if not ok2 then
              term.setTextColor(colors.red)
              print("Command error:", err)
              term.setTextColor(colors.white)
            end
            matched = true
            break
          end
        end
        
        if not matched then
          local sane = sanitizeName(cmd)
          if sane and tryRunPackageByName(sane, args) then
            matched = true
          end
        end
        
        if not matched then
          
          local gbinPath = GBIN_DIR .. "/" .. cmd .. ".lua"
          if fs.exists(gbinPath) and isPathInDir(gbinPath, GBIN_DIR) then
            runOnTop(gbinPath, args)
            matched = true
          else
            
            local binPath = BIN_DIR .. "/" .. cmd .. ".lua"
            if fs.exists(binPath) and isPathInDir(binPath, BIN_DIR) then
              
              runBinSilent(binPath, args)
              matched = true
            end
          end
        end
        
        if not matched then
          if cmd:find("/") then
            
            local path = cmd
            if fs.exists(path) then
              
              if isPathInDir(path, GUI_PACKAGES_DIR) then
                runOnTop(path, args)
              elseif isPathInDir(path, GBIN_DIR) then
                runOnTop(path, args)
              elseif isPathInDir(path, BIN_DIR) then
                
                runBinSilent(path, args)
              else
                
                runNormally(path, args)
              end
            else
              term.setTextColor(colors.red)
              print("Path not found: " .. tostring(path))
              term.setTextColor(colors.white)
            end
          else
            
            local okCraft, craftErr = pcall(function()
              if args and #args > 0 then shell.run(cmd, unpack(args)) else shell.run(cmd) end
            end)
            if not okCraft then
              term.setTextColor(colors.red)
              print("craftOS error or unknown command: " .. tostring(craftErr))
              term.setTextColor(colors.white)
            end
            matched = true
          end
        end
      end
    end
  end
end

local function findOnTopProgramCandidate(p)
  if type(p) ~= "string" then return nil, nil end
  if p:sub(1,1) == "/" then
    if fs.exists(p) and isPathInDir(p, GUI_PACKAGES_DIR) then
      return "gui", p
    elseif fs.exists(p) and isPathInDir(p, GBIN_DIR) then
      return "gbin", p
    else
      return nil, nil
    end
  else
    
    local gbinPath = GBIN_DIR .. "/" .. p .. ".lua"
    if fs.exists(gbinPath) and isPathInDir(gbinPath, GBIN_DIR) then return "gbin", gbinPath end
    local guiPath = GUI_PACKAGES_DIR .. "/" .. p .. ".lua"
    if fs.exists(guiPath) and isPathInDir(guiPath, GUI_PACKAGES_DIR) then return "gui", guiPath end
    return nil, nil
  end
end

if initArgs and #initArgs > 0 and initArgs[1] ~= "" then
  local prog = initArgs[1]
  local progArgs = {}
  for i = 2, #initArgs do progArgs[#progArgs + 1] = initArgs[i] end
  local onType, onPath = findOnTopProgramCandidate(prog)
  local function runOnTopProgram()
    local ok, err = pcall(function()
      if onPath then
        shell.run(onPath, unpack(progArgs))
      else
        if prog:sub(1,1) == "/" then
          
          if fs.exists(prog) then
            if isPathInDir(prog, GUI_PACKAGES_DIR) or isPathInDir(prog, GBIN_DIR) then
              runOnTop(prog, progArgs)
            elseif isPathInDir(prog, BIN_DIR) then
              runBinSilent(prog, progArgs)
            else
              runNormally(prog, progArgs)
            end
          else
            term.setTextColor(colors.red)
            print("Init path not found: " .. tostring(prog))
            term.setTextColor(colors.white)
          end
        else
          
          local sane = sanitizeName(prog)
          if sane and tryRunPackageByName(sane, progArgs) then
            
          else
            local gbinPath = GBIN_DIR .. "/" .. prog .. ".lua"
            if fs.exists(gbinPath) and isPathInDir(gbinPath, GBIN_DIR) then
              runOnTop(gbinPath, progArgs)
            else
              local binPath = BIN_DIR .. "/" .. prog .. ".lua"
              if fs.exists(binPath) and isPathInDir(binPath, BIN_DIR) then
                runBinSilent(binPath, progArgs)
              else
                term.setTextColor(colors.red)
                print("Init program not found (use full path or place in /ninx/.sys/bin or /ninx/packages): " .. tostring(prog))
                term.setTextColor(colors.white)
              end
            end
          end
        end
      end
    end)
    if not ok then
      term.setTextColor(colors.red)
      print("Program error:", tostring(err))
      term.setTextColor(colors.white)
    end
    term.setTextColor(colors.white)
    print("\nReturned to Ninx Shell.")
    safeSetCursorBlink(true)
  end
  if onPath then
    if parallel and type(parallel.waitForAny) == "function" then
      parallel.waitForAny(
        function() pcall(repl) end,
        function() pcall(runOnTopProgram) end
      )
      pcall(repl)
    else
      pcall(runOnTopProgram)
      pcall(repl)
    end
  else
    
    local normalBin = BIN_DIR .. "/" .. prog .. ".lua"
    if fs.exists(normalBin) and isPathInDir(normalBin, BIN_DIR) then
      runBinSilent(normalBin, progArgs)
      pcall(repl)
    else
      
      local sane = sanitizeName(prog)
      if sane and tryRunPackageByName(sane, progArgs) then
        pcall(repl)
      else
        local gbinPath = GBIN_DIR .. "/" .. prog .. ".lua"
        if fs.exists(gbinPath) and isPathInDir(gbinPath, GBIN_DIR) then
          runOnTop(gbinPath, progArgs)
          pcall(repl)
        else
          local binPath = BIN_DIR .. "/" .. prog .. ".lua"
          if fs.exists(binPath) and isPathInDir(binPath, BIN_DIR) then
            runBinSilent(binPath, progArgs)
            pcall(repl)
          else
            
            local okCraft, craftErr = pcall(function()
              if #progArgs > 0 then shell.run(prog, unpack(progArgs)) else shell.run(prog) end
            end)
            if not okCraft then
              term.setTextColor(colors.red)
              print("Init program not found or craftOS error: " .. tostring(craftErr))
              term.setTextColor(colors.white)
            end
            pcall(repl)
          end
        end
      end
    end
  end
else
  repl()
end