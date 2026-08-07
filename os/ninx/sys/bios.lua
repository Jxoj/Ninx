

local term = term
local fs = fs
local os = os
local keys = keys
local colors = colors
local sleep = sleep
local CONFIG_PATH = "/ninx/.sys/config/sys.cfg"

local tabs = {"Interface", "Exit"}
local currentTab = 1
local interfaceItems = {"Windowmanger"}
local wmChoices = {"Default", "Graphical"}
local function ensureConfigFile()
    if not fs.exists(CONFIG_PATH) then
        local dir = fs.getDir(CONFIG_PATH)
        if dir and not fs.exists(dir) then fs.makeDir(dir) end
        local f = fs.open(CONFIG_PATH, "w")
        if f then f.close() end
    end
end
local function readConfigLines()
    ensureConfigFile()
    local f = fs.open(CONFIG_PATH, "r")
    if not f then return {} end
    local lines = {}
    while true do
        local ln = f.readLine()
        if not ln then break end
        table.insert(lines, ln)
    end
    f.close()
    return lines
end
local function writeConfigLines(lines)
    local dir = fs.getDir(CONFIG_PATH)
    if dir and not fs.exists(dir) then fs.makeDir(dir) end
    local f = fs.open(CONFIG_PATH, "w")
    if not f then return false end
    for _, l in ipairs(lines) do f.writeLine(l) end
    f.close(); return true
end
local function getCurrentWMFromConfig()
    local lines = readConfigLines()
    for _, l in ipairs(lines) do local v = l:match("^Windowmanger:(%w+)"); if v then return v end end
    for _, l in ipairs(lines) do local v = l:match("^Windowmanger(%w+)"); if v then return v end end
    return "Default"
end
local function replaceOrInsertWindowmanger(value)
    if not value or type(value) ~= "string" then return false end
    if not value:match("^%w+$") then return false end
    local lines = readConfigLines(); local found = false
    for i, l in ipairs(lines) do if l:match("^Windowmanger:") or l:match("^Windowmanger%w+$") then lines[i] = "Windowmanger:" .. value; found = true; break end end
    if not found then table.insert(lines, "Windowmanger:" .. value) end
    return writeConfigLines(lines)
end
local stagedWM = getCurrentWMFromConfig()
local unsaved = false
local selInterface = 1
local selWM = 1
for i,v in ipairs(wmChoices) do if v:lower() == stagedWM:lower() then selWM = i; break end end
local depth = 1
local C_BG = colors.black
local C_TEXT = colors.white
local C_HEADER = colors.orange
local C_HEADER_TEXT = colors.white
local C_SEL_BG = colors.black
local C_SEL_TEXT = colors.white
local function clearLine(y) local w,_=term.getSize(); term.setCursorPos(1,y); term.write(string.rep(" ", w)); term.setCursorPos(1,y) end
local function centerText(y, text) local w,_=term.getSize(); local x = math.floor((w-#text)/2)+1; if x<1 then x=1 end; term.setCursorPos(x,y); term.write(text) end
local function drawTabs()
    local w,_=term.getSize(); term.setCursorPos(1,1); term.setBackgroundColor(C_HEADER); term.setTextColor(C_HEADER_TEXT)
    local curX=1; for _, name in ipairs(tabs) do local out=" ["..name.."] "; term.setCursorPos(curX,1); term.write(out); curX=curX+#out end
    if curX<=w then term.setCursorPos(curX,1); term.write(string.rep(" ", w-curX+1)) end
    term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT)
end
local function drawUI()
    term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT); term.clear()
    drawTabs()
    term.setBackgroundColor(C_HEADER); term.setTextColor(C_HEADER_TEXT); clearLine(2); centerText(2, "NINX BIOS CONFIG"); term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT)
    clearLine(3); centerText(3, "Navigation: Arrow Keys / Enter. Back: Backspace / Esc / Delete")
    if currentTab == 1 then
        clearLine(4); term.setCursorPos(1,4); term.write(" Interface")
        for i, item in ipairs(interfaceItems) do local y=6+(i-1); if depth==2 and i==selInterface then term.setBackgroundColor(C_SEL_BG); term.setTextColor(C_SEL_TEXT); clearLine(y); term.setCursorPos(3,y); term.write(">"..item) else term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT); clearLine(y); term.setCursorPos(3,y); term.write("  "..item) end end
        if depth == 3 then
            local labY=8; term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT); clearLine(labY); term.setCursorPos(12,labY); term.write("Windowmanger:")
            for i,opt in ipairs(wmChoices) do local y=9+i; if i==selWM then term.setBackgroundColor(C_SEL_BG); term.setTextColor(C_SEL_TEXT); clearLine(y); term.setCursorPos(14,y); term.write("> "..opt) else term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT); clearLine(y); term.setCursorPos(14,y); term.write("   "..opt) end end
        end
        term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT); clearLine(14); term.setCursorPos(1,14); term.write("Current: "..getCurrentWMFromConfig()); clearLine(15); term.setCursorPos(1,15); term.write("Staged:  "..stagedWM..(unsaved and " (unsaved)" or ""))
    else
        clearLine(4); term.setCursorPos(1,4); term.write(" Exit")
        clearLine(6); term.setCursorPos(3,6); if depth==2 then term.setBackgroundColor(C_SEL_BG); term.setTextColor(C_SEL_TEXT) else term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT) end
        if unsaved then term.write(" Save changes and Exit ") else term.write(" Exit (no changes) ") end
    end
    term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT)
end
local function cleanup() term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1) end
local function tabLeft() if depth==1 then currentTab=currentTab-1; if currentTab<1 then currentTab=#tabs end end end
local function tabRight() if depth==1 then currentTab=currentTab+1; if currentTab>#tabs then currentTab=1 end end end
local function moveUp() if currentTab==1 then if depth==2 then if selInterface>1 then selInterface=selInterface-1 else depth=1 end elseif depth==3 then if selWM>1 then selWM=selWM-1 else depth=1 end else currentTab=currentTab-1; if currentTab<1 then currentTab=#tabs end end else if depth==2 then depth=1 else currentTab=currentTab-1; if currentTab<1 then currentTab=#tabs end end end end
local function moveDown() if currentTab==1 then if depth==1 then depth=2; if selInterface<1 or selInterface>#interfaceItems then selInterface=1 end elseif depth==2 then selInterface=selInterface+1; if selInterface>#interfaceItems then selInterface=1 end elseif depth==3 then selWM=selWM+1; if selWM>#wmChoices then selWM=1 end end else if depth==1 then depth=2 end end end
local function doEnter() if currentTab==1 then if depth==1 then depth=2; if selInterface<1 or selInterface>#interfaceItems then selInterface=1 end elseif depth==2 then if interfaceItems[selInterface]=="Windowmanger" then depth=3; for i,v in ipairs(wmChoices) do if v:lower()==stagedWM:lower() then selWM=i; break end end; if selWM<1 then selWM=1 end end elseif depth==3 then stagedWM=wmChoices[selWM]; unsaved=true; term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT); term.clear(); centerText(8, "Staged Windowmanger: "..stagedWM); centerText(10, "Go to Exit and press Enter to save & quit."); sleep(0.9); depth=2 end else if unsaved then replaceOrInsertWindowmanger(stagedWM) end; cleanup(); if unsaved then print("Saved Windowmanger:"..stagedWM) else print("Exited BIOS (no changes).") end; return true end return false end
local function doBack() if depth==3 then depth=2 elseif depth==2 then depth=1 else cleanup(); print("Exited BIOS without saving staged changes."); return true end return false end
local REPEAT_INITIAL = 0.30; local REPEAT_RATE = 0.06; local repeatKey=nil; local repeatTimerId=nil
local function startRepeat(k) if repeatTimerId then pcall(os.cancelTimer, repeatTimerId); repeatTimerId=nil end; repeatKey=k; repeatTimerId=os.startTimer(REPEAT_INITIAL) end
local function stopRepeat(k) if repeatKey and k==repeatKey then if repeatTimerId then pcall(os.cancelTimer, repeatTimerId); repeatTimerId=nil end; repeatKey=nil end end
local function processKey(k) if k==keys.left then tabLeft() elseif k==keys.right then tabRight() elseif k==keys.up then moveUp() elseif k==keys.down then moveDown() elseif k==keys.enter then local done=doEnter(); if done then return "exit" end elseif k==keys.backspace or k==keys.delete or k==keys.escape then local done=doBack(); if done then return "exit" end end return nil end
term.setBackgroundColor(C_BG); term.setTextColor(C_TEXT); term.clear(); drawUI()
local running=true; while running do local ev={os.pullEvent()}; local evName=ev[1]; if evName=="key" then local k=ev[2]; local res=processKey(k); if res=="exit" then running=false break end; drawUI(); if k==keys.left or k==keys.right or k==keys.up or k==keys.down then startRepeat(k) end elseif evName=="key_up" then local k_up=ev[2]; stopRepeat(k_up) elseif evName=="timer" then local tId=ev[2]; if repeatKey and repeatTimerId and tId==repeatTimerId then local res=processKey(repeatKey); if res=="exit" then running=false break end; drawUI(); if repeatTimerId then pcall(os.cancelTimer, repeatTimerId) end; repeatTimerId=os.startTimer(REPEAT_RATE) end end end
cleanup()