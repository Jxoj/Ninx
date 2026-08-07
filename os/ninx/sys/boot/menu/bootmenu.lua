
local optionsFile = "/ninx/.sys/boot/options.txt"
local baseOptions = {
  { name = "Ninx", path = "/ninx/.sys/boot/ninx.lua" },
  { name = "CraftOS", special = "craftos" },
  { name = "Shutdown", path = "/ninx/.sys/boot/menu/shutdown1.lua" },
  { name = "Reboot", path = "/ninx/.sys/boot/menu/reboot1.lua" },
  { name = "Add Option", special = "add" },
}
local timeout = 7
local defaultIndex = 1
local countdownActive = true
local function ensureDirForFile(path)
  local parent = path:match("(.*/)")
  if parent and not fs.exists(parent) then fs.makeDir(parent) end
end
local function load_custom_options()
  local customs = {}
  if fs.exists(optionsFile) then
    local fh = fs.open(optionsFile, "r")
    if fh then
      while true do
        local line = fh.readLine(); if not line then break end
        local name, path = line:match("([^\t]+)\t(.+)")
        if name and path then table.insert(customs, { name = name, path = path }) end
      end
      fh.close()
    end
  end
  return customs
end
local function save_custom_options(customs)
  ensureDirForFile(optionsFile)
  local fh = fs.open(optionsFile, "w")
  if not fh then print("Error: cannot open " .. optionsFile .. " for writing."); sleep(2); return false end
  for _, opt in ipairs(customs) do fh.writeLine(opt.name .. "\t" .. opt.path) end
  fh.close(); return true
end
local customOptions = load_custom_options()
local function build_options()
  local opts = {}
  for _, o in ipairs(baseOptions) do
    if o.name == "Shutdown" then for _, c in ipairs(customOptions) do table.insert(opts, { name = c.name, path = c.path }) end end
    table.insert(opts, o)
  end
  local hasShutdown=false; for _,o in ipairs(baseOptions) do if o.name=="Shutdown" then hasShutdown=true end end
  if not hasShutdown then for _, c in ipairs(customOptions) do table.insert(opts, { name = c.name, path = c.path }) end end
  return opts
end
local function clearScreen()
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
end
local function centerText(y, text, textColor)
  local w,_=term.getSize(); term.setCursorPos(math.floor((w-#text)/2)+1, y); term.setTextColor(textColor or colors.white); term.write(text); term.setTextColor(colors.white)
end
local function drawMenu(options, selected, countdown)
  clearScreen(); centerText(2, "Ninx Bootmenu", colors.blue); centerText(4, "Use Up/Down to choose, Enter to boot", colors.lightGray)
  for i, opt in ipairs(options) do
    term.setCursorPos(5, i+6); term.setBackgroundColor(colors.black)
    if i == selected then term.setTextColor(colors.purple); write("> "..opt.name.." <"); term.setTextColor(colors.white) else term.setTextColor(colors.white); write("  "..opt.name) end
  end
  term.setCursorPos(1,15); term.setBackgroundColor(colors.black); term.setTextColor(colors.lightGray)
  if countdownActive then centerText(15, "Booting default in "..countdown.."s") else centerText(15, "Press Enter to boot") end
  term.setTextColor(colors.white)
end
local function boot(opt)
  clearScreen(); term.setCursorPos(1,1)
  if opt.special == "craftos" then shell.run("rom/programs/shell.lua")
  elseif opt.special == "add" then return
  elseif opt.path and fs.exists(opt.path) then shell.run(opt.path)
  else print("Error: "..(opt.path or "No path").." not found!"); sleep(2) end
end
local function prompt_add_option()
  clearScreen(); term.setCursorPos(1,1); term.setTextColor(colors.white)
  print("Add Option")
  print("----------")
  write("Name: "); local name = read(); if not name or name:match("^%s*$") then print("Cancelled: name cannot be empty."); sleep(1.5); return false end
  write("Program Path: "); local path = read(); if not path or path:match("^%s*$") then print("Cancelled: path cannot be empty."); sleep(1.5); return false end
  if not fs.exists(path) then print("Warning: path does not exist right now. Save anyway? (y/n)"); local ans = read(); if not (ans and (ans:lower():sub(1,1) == "y")) then print("Add cancelled."); sleep(1.2); return false end end
  table.insert(customOptions, { name = name, path = path }); local ok = save_custom_options(customOptions); if ok then print("Option added and saved.") else print("Option added (not saved).") end; sleep(1.2); return true
end
local selected = defaultIndex; local countdown = timeout; local timer = os.startTimer(1)
while true do
  local options = build_options(); drawMenu(options, selected, countdown)
  local e, p = os.pullEvent()
  if e == "key" then
    if p == keys.up then selected = selected - 1; if selected < 1 then selected = #options end; countdownActive = false; drawMenu(options, selected, countdown)
    elseif p == keys.down then selected = selected + 1; if selected > #options then selected = 1 end; countdownActive = false; drawMenu(options, selected, countdown)
    elseif p == keys.enter then local opt = options[selected]; if opt then if opt.special == "add" then countdownActive = false; local added = prompt_add_option(); options = build_options(); if added then local lastName = customOptions[#customOptions].name; for i, o in ipairs(options) do if o.name == lastName and o.path then selected = i; break end end end; drawMenu(options, selected, countdown) else boot(opt); break end end end
  elseif e == "timer" and p == timer then if countdownActive then countdown = countdown - 1; if countdown <= 0 then local optionsNow = build_options(); boot(optionsNow[defaultIndex]); break else drawMenu(options, selected, countdown) end end; timer = os.startTimer(1) end
end