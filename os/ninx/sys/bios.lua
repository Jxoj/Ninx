-- bios.lua  Ninx BIOS Configuration Utility  v2.0
-- Orange/black theme. Called by kernel when 'B' pressed during boot.
-- Returns cleanly without crashing the caller.

local CONFIG_PATH = "/ninx/.sys/config/sys.cfg"

-- ─── Colours ─────────────────────────────────────────────────────────────────
local C_BG      = colors.black
local C_FG      = colors.white
local C_ACCENT  = colors.orange
local C_SEL_BG  = colors.orange
local C_SEL_FG  = colors.black
local C_DIM     = colors.gray
local C_ERR     = colors.red

-- ─── Term helpers ─────────────────────────────────────────────────────────────
local W, H = term.getSize()
local function clrScr()
  term.setBackgroundColor(C_BG); term.setTextColor(C_FG); term.clear()
end
local function cur(x,y) term.setCursorPos(x,y) end
local function clrLine(y)
  cur(1,y); term.setBackgroundColor(C_BG); term.write(string.rep(" ",W))
end
local function center(y, text, fg, bg)
  bg = bg or C_BG; fg = fg or C_FG
  local x = math.max(1, math.floor((W - #text)/2)+1)
  cur(x,y); term.setBackgroundColor(bg); term.setTextColor(fg); term.write(text)
  term.setBackgroundColor(C_BG); term.setTextColor(C_FG)
end
local function header()
  clrLine(1)
  center(1, " NINX BIOS v2.0 ", C_SEL_FG, C_SEL_BG)
  clrLine(2)
  term.setTextColor(C_DIM); cur(2,2)
  term.write("Arrows: navigate   Enter: select   Esc/Backspace: back")
  term.setTextColor(C_FG)
end
local function footer(msg)
  clrLine(H); cur(2,H)
  term.setTextColor(C_DIM); term.write(msg or ""); term.setTextColor(C_FG)
end
local function drawBox(y1,x1,y2,x2,title)
  for y=y1,y2 do
    clrLine(y)
    cur(x1,y); term.write("|")
    cur(x2,y); term.write("|")
  end
  cur(x1,y1)
  term.write("+" .. string.rep("-", x2-x1-1) .. "+")
  cur(x1,y2)
  term.write("+" .. string.rep("-", x2-x1-1) .. "+")
  if title then
    local tx = x1+2; cur(tx,y1)
    term.setTextColor(C_ACCENT); term.write("[" .. title .. "]"); term.setTextColor(C_FG)
  end
end

-- ─── Config I/O ───────────────────────────────────────────────────────────────
local function ensureConfig()
  local d = fs.getDir(CONFIG_PATH)
  if d and not fs.exists(d) then fs.makeDir(d) end
  if not fs.exists(CONFIG_PATH) then
    local f=fs.open(CONFIG_PATH,"w"); if f then f.close() end
  end
end

local function readConfig()
  ensureConfig()
  local cfg = {}
  local f = fs.open(CONFIG_PATH,"r"); if not f then return cfg end
  while true do
    local l = f.readLine(); if not l then break end
    local k,v = l:match("^([^:]+):(.+)$")
    if k then cfg[k:match("^%s*(.-)%s*$")] = v:match("^%s*(.-)%s*$") end
  end
  f.close(); return cfg
end

local function writeConfig(cfg)
  ensureConfig()
  local f = fs.open(CONFIG_PATH,"w"); if not f then return false end
  for k,v in pairs(cfg) do f.writeLine(k..":"..v) end
  f.close(); return true
end

-- ─── Menus ────────────────────────────────────────────────────────────────────
local cfg        = readConfig()
local unsaved    = false
local running    = true

-- tab definitions: { id, label }
local TABS = { {id="interface",label="Interface"}, {id="about",label="About"}, {id="exit",label="Exit"} }
local tabIdx   = 1
local selIdx   = 1   -- selection within a tab
local depth    = 1   -- 1=tab row, 2=item, 3=sub-choice

-- Interface items
local WM_OPTIONS = {"Default","Graphical"}
local function wmIndex()
  local v = (cfg.Windowmanger or "Default")
  for i,o in ipairs(WM_OPTIONS) do if o:lower()==v:lower() then return i end end
  return 1
end
local stagedWM = WM_OPTIONS[wmIndex()]

-- ─── Render ───────────────────────────────────────────────────────────────────
local function renderInterface()
  local startY = 4
  local items  = { "Window Manager" }
  for i,item in ipairs(items) do
    local y = startY + (i-1)*2
    clrLine(y)
    cur(3,y)
    if depth >= 2 and i == selIdx then
      term.setBackgroundColor(C_SEL_BG); term.setTextColor(C_SEL_FG)
      term.write(" > " .. item .. " ")
      term.setBackgroundColor(C_BG); term.setTextColor(C_FG)
    else
      term.setTextColor(C_ACCENT); term.write("  "); term.setTextColor(C_FG)
      term.write(item)
    end
    -- show current value
    clrLine(y+1)
    cur(6,y+1)
    term.setTextColor(C_DIM)
    if item == "Window Manager" then
      term.write("Current: " .. (cfg.Windowmanger or "Default"))
      if unsaved and stagedWM ~= (cfg.Windowmanger or "Default") then
        term.setTextColor(C_ACCENT); term.write("  Staged: " .. stagedWM)
      end
    end
    term.setTextColor(C_FG)
  end
  if depth == 3 then
    -- WM choice sub-menu
    local boxY1, boxY2 = 4, 4+#WM_OPTIONS+1
    drawBox(boxY1, W-20, boxY2, W-2, "Choose WM")
    for i,opt in ipairs(WM_OPTIONS) do
      local y = boxY1+i
      cur(W-19,y)
      if i == selIdx then
        term.setBackgroundColor(C_SEL_BG); term.setTextColor(C_SEL_FG)
        term.write(" > " .. opt .. string.rep(" ", 15-#opt))
        term.setBackgroundColor(C_BG); term.setTextColor(C_FG)
      else
        term.write("   " .. opt)
      end
    end
  end
end

local function renderAbout()
  local y = 4
  center(y,   "Ninx Operating System",  C_ACCENT)
  center(y+1, "BIOS Configuration Utility v2.0", C_DIM)
  center(y+3, "Boot by pressing B during kernel startup", C_FG)
  center(y+4, "Settings are saved to: " .. CONFIG_PATH, C_DIM)
end

local function renderExit()
  local y = 5
  if unsaved then
    center(y,   "You have unsaved changes!", C_ERR)
    center(y+2, "> Save & Exit <", C_SEL_FG, C_SEL_BG)
    center(y+3, "  Discard & Exit", depth>=2 and C_ACCENT or C_FG)
  else
    center(y+1, "> Exit BIOS <", C_SEL_FG, C_SEL_BG)
    center(y+2, "No changes to save.", C_DIM)
  end
end

local function renderTabs()
  clrLine(3)
  local x = 2
  for i,tab in ipairs(TABS) do
    cur(x,3)
    if i == tabIdx then
      term.setBackgroundColor(C_ACCENT); term.setTextColor(C_SEL_FG)
      term.write(" [" .. tab.label .. "] ")
      term.setBackgroundColor(C_BG); term.setTextColor(C_FG)
    else
      term.setTextColor(C_DIM); term.write("  " .. tab.label .. "  "); term.setTextColor(C_FG)
    end
    x = x + #tab.label + 5
  end
end

local function redraw()
  clrScr()
  header()
  renderTabs()
  clrLine(H-1)
  local tab = TABS[tabIdx].id
  if tab == "interface" then
    renderInterface()
    footer("Enter=select  Arrows=navigate  Esc=back")
  elseif tab == "about" then
    renderAbout()
    footer("Press Esc or Tab to switch tabs")
  elseif tab == "exit" then
    renderExit()
    footer("Enter=confirm  Esc=cancel")
  end
end

-- ─── Input handling ───────────────────────────────────────────────────────────
local function doSave()
  cfg.Windowmanger = stagedWM
  writeConfig(cfg)
  unsaved = false
end

local function handleExit()
  local tab = TABS[tabIdx].id
  if tab == "exit" then
    if unsaved then
      -- selIdx 1=Save&Exit, 2=Discard&Exit
      if selIdx == 1 or selIdx == 0 then doSave() end
    end
    running = false
    return
  end
  if depth == 3 then depth = 2; return end
  if depth == 2 then depth = 1; selIdx = 1; return end
  if depth == 1 then tabIdx = #TABS; redraw(); return end  -- jump to exit tab
end

local function handleEnter()
  local tab = TABS[tabIdx].id
  if depth == 1 then
    depth = 2; selIdx = 1; return
  end
  if tab == "interface" then
    if depth == 2 then
      depth = 3
      -- for WM, reset selIdx to current staged
      for i,o in ipairs(WM_OPTIONS) do if o==stagedWM then selIdx=i break end end
    elseif depth == 3 then
      -- confirm WM selection
      stagedWM = WM_OPTIONS[selIdx]
      if stagedWM ~= (cfg.Windowmanger or "Default") then unsaved = true end
      depth = 2; selIdx = 1
    end
  elseif tab == "exit" then
    if unsaved then
      if selIdx == 1 then doSave() end
    end
    running = false
  end
end

local function handleUp()
  if depth == 1 then
    tabIdx = tabIdx - 1; if tabIdx < 1 then tabIdx = #TABS end
  elseif depth == 2 then
    local tab = TABS[tabIdx].id
    if tab == "interface" then
      selIdx = selIdx - 1; if selIdx < 1 then selIdx = 1 end
    elseif tab == "exit" and unsaved then
      selIdx = selIdx - 1; if selIdx < 1 then selIdx = 1 end
    end
  elseif depth == 3 then
    selIdx = selIdx - 1; if selIdx < 1 then selIdx = #WM_OPTIONS end
  end
end

local function handleDown()
  if depth == 1 then
    tabIdx = tabIdx + 1; if tabIdx > #TABS then tabIdx = 1 end
  elseif depth == 2 then
    local tab = TABS[tabIdx].id
    if tab == "interface" then
      selIdx = selIdx + 1; if selIdx > 1 then selIdx = 1 end
    elseif tab == "exit" and unsaved then
      selIdx = selIdx + 1; if selIdx > 2 then selIdx = 2 end
    end
  elseif depth == 3 then
    selIdx = selIdx + 1; if selIdx > #WM_OPTIONS then selIdx = 1 end
  end
end

local function handleLeft()
  if depth == 1 then tabIdx=tabIdx-1; if tabIdx<1 then tabIdx=#TABS end end
end
local function handleRight()
  if depth == 1 then tabIdx=tabIdx+1; if tabIdx>#TABS then tabIdx=1 end end
end

-- ─── Main loop ────────────────────────────────────────────────────────────────
redraw()

while running do
  local ev, p = os.pullEvent("key")
  if     p == keys.up       then handleUp()
  elseif p == keys.down     then handleDown()
  elseif p == keys.left     then handleLeft()
  elseif p == keys.right    then handleRight()
  elseif p == keys.enter    then handleEnter()
  elseif p == keys.backspace or p == keys.escape or p == keys["delete"] then handleExit()
  end
  if running then redraw() end
end

-- Clean exit — restore terminal
term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
if unsaved then
  term.setTextColor(colors.orange); print("BIOS: exited without saving staged changes.")
  term.setTextColor(colors.white)
end