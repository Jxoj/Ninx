
local function colourPrint(tag, tagColor, msg)
  term.setTextColor(colors.white)
  io.write("[")
  term.setTextColor(tagColor)
  io.write(tag)
  term.setTextColor(colors.white)
  io.write("] ")
  print(msg)
end
colourPrint("Success", colors.green, "Attempting to start workspace.")
local function getWindowManager()
    local path = "/ninx/.sys/config/sys.cfg"
    if not fs.exists(path) then
        return "Default"
    end
    local file = fs.open(path, "r")
    if not file then
        return "Default"
    end
    local manager = "Default"
    while true do
        local line = file.readLine()
        if not line then break end
        local key, value = line:match("^(%S+):%s*(%S+)$")
        if key == "Windowmanager" or key == "Windowmanger" then
            manager = value
            break
        end
    end
    file.close()
    return manager
end
local wm = getWindowManager()
local script = "/ninx/.sys/boot/desktop/workspace.lua"
if wm == "Graphical" then
    script = "/ninx/.sys/boot/desktop/gwm.lua"
end
local ok, err = pcall(function()
    shell.run("/ninx/.sys/utils/loading.lua", script)
end)
if not ok then
    colourPrint("Error", colors.red, err)
end
if ok then
  colourPrint("Success", colors.green, "Workspace started successfully.")
  sleep(1)
  return
else
  colourPrint("Error", colors.red, "Failed to start workspace: " .. tostring(err))
  sleep(0.5)
  colourPrint("Success", colors.green, "Attempting to boot to BIOS (/ninx/.sys/bios.lua).")
  local ok2, err2 = pcall(function() shell.run("/ninx/.sys/bios.lua") end)
  if ok2 then
    colourPrint("Success", colors.green, "BIOS started (fallback) successfully.")
    sleep(1)
    return
  else
    colourPrint("Error", colors.red, "Failed to start BIOS: " .. tostring(err2))
    
  end
end
sleep(1)
local function colourPrint(tag, tagColor, msg)
  term.setTextColor(colors.white)
  io.write("[")
  term.setTextColor(tagColor)
  io.write(tag)
  term.setTextColor(colors.white)
  io.write("] ")
  print(msg)
end
colourPrint("Success", colors.green, "Attempting to start workspace.")
local function getWindowManager()
  local path = "/ninx/.sys/config/sys.cfg"
  if not fs.exists(path) then return "Default" end
  local file = fs.open(path, "r"); if not file then return "Default" end
  local manager = "Default"
  while true do local line = file.readLine(); if not line then break end
    local key, value = line:match("^(%S+):%s*(%S+)$")
    if key == "Windowmanager" or key == "Windowmanger" then manager = value; break end
  end
  file.close(); return manager
end
local wm = getWindowManager()
local script = "/ninx/.sys/boot/desktop/workspace.lua"
if wm == "Graphical" then script = "/ninx/.sys/boot/desktop/gwm.lua" end
local ok, err = pcall(function() shell.run("/ninx/.sys/utils/loading.lua", script) end)
if not ok then colourPrint("Error", colors.red, err) end
if ok then colourPrint("Success", colors.green, "Workspace started successfully."); sleep(1); return
else colourPrint("Error", colors.red, "Failed to start workspace: " .. tostring(err)); sleep(0.5); colourPrint("Success", colors.green, "Attempting to boot to BIOS (/ninx/.sys/bios.lua).")
  local ok2, err2 = pcall(function() shell.run("/ninx/.sys/bios.lua") end)
  if ok2 then colourPrint("Success", colors.green, "BIOS started (fallback) successfully."); sleep(1); return
  else colourPrint("Error", colors.red, "Failed to start BIOS: " .. tostring(err2)); return end
end