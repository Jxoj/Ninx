

local term = term
local colors = colors
local shell = shell
local fs = fs
local tArgs = { ... }
local nextProgram = tArgs[1]
if not nextProgram then print("Usage: apis/loadingscreen.lua <program_path>"); return end
local w, h = term.getSize()
local radius = math.floor(math.min(w, h) / 3)
local cells = 24
local rotationSpeed = 4.5
local frameDelay = 0.05
local duration = 3
local cx = math.floor(w / 2)
local cy = math.floor(h / 2)
local function fillBackground() term.setBackgroundColor(colors.purple); term.clear() end
local function drawSpinner(phase)
  term.setBackgroundColor(colors.purple); term.setTextColor(colors.white)
  local drawn = {}
  for i = 0, cells - 1 do
    local angle = (i / cells) * (2 * math.pi) + phase
    local x = math.floor(cx + math.cos(angle) * radius + 0.5)
    local y = math.floor(cy + math.sin(angle) * radius * 0.5 + 0.5)
    local key = x .. "," .. y
    if not drawn[key] and x >= 1 and x <= w and y >= 1 and y <= h then
      drawn[key] = true
      term.setCursorPos(x, y)
      term.setBackgroundColor(colors.white)
      term.write(" ")
    end
  end
  term.setBackgroundColor(colors.purple)
end
local function runSpinner()
  if term.setCursorBlink then pcall(term.setCursorBlink, false) end
  local startTime = os.clock(); local phase = 0; local lastTime = os.clock()
  while os.clock() - startTime < duration do
    local now = os.clock(); local dt = now - lastTime; lastTime = now; phase = phase + rotationSpeed * dt
    fillBackground(); drawSpinner(phase); sleep(frameDelay)
  end
end
fillBackground(); runSpinner()
term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1, 1); if term.setCursorBlink then pcall(term.setCursorBlink, true) end
if fs.exists(nextProgram) then shell.run(nextProgram) else print("Error: Program not found: " .. nextProgram) end