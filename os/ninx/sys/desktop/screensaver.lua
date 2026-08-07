

local term = term
local scr_x, scr_y = term.getSize()
local title = "Ninx Shell"
local digits = {
    ["0"] = { {1,1,1,1,1},{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{1,1,1,1,1}, },
    ["1"] = { {0,0,1,0,0},{0,1,1,0,0},{1,0,1,0,0},{0,0,1,0,0},{1,1,1,1,1}, },
    ["2"] = { {1,1,1,1,1},{0,0,0,0,1},{1,1,1,1,1},{1,0,0,0,0},{1,1,1,1,1}, },
    ["3"] = { {1,1,1,1,1},{0,0,0,0,1},{0,1,1,1,1},{0,0,0,0,1},{1,1,1,1,1}, },
    ["4"] = { {1,0,0,0,1},{1,0,0,0,1},{1,1,1,1,1},{0,0,0,0,1},{0,0,0,0,1}, },
    ["5"] = { {1,1,1,1,1},{1,0,0,0,0},{1,1,1,1,1},{0,0,0,0,1},{1,1,1,1,1}, },
    ["6"] = { {1,1,1,1,1},{1,0,0,0,0},{1,1,1,1,1},{1,0,0,0,1},{1,1,1,1,1}, },
    ["7"] = { {1,1,1,1,1},{0,0,0,0,1},{0,0,0,1,0},{0,0,1,0,0},{0,0,1,0,0}, },
    ["8"] = { {1,1,1,1,1},{1,0,0,0,1},{1,1,1,1,1},{1,0,0,0,1},{1,1,1,1,1}, },
    ["9"] = { {1,1,1,1,1},{1,0,0,0,1},{1,1,1,1,1},{0,0,0,0,1},{1,1,1,1,1}, },
    [":"] = { {0,0,0,0,0},{0,1,0,1,0},{0,0,0,0,0},{0,1,0,1,0},{0,0,0,0,0}, }
}
term.setBackgroundColor(colors.purple)
term.clear()
local function drawTitle()
    term.setBackgroundColor(colors.purple)
    term.setTextColor(colors.white)
    local x = math.max(1, math.floor((scr_x - #title) / 2))
    term.setCursorPos(x, 1)
    term.write(title)
end
local function drawDigit(x, y, ch)
    local pattern = digits[ch]
    if not pattern then return end
    for r = 1, 5 do
        for c = 1, 5 do
            term.setCursorPos(x + c - 1, y + r - 1)
            if pattern[r][c] == 1 then
                term.setBackgroundColor(colors.white)
            else
                term.setBackgroundColor(colors.purple)
            end
            term.write(" ")
        end
    end
end
local function drawTimeString(timeStr)
    local charCount = #timeStr
    local totalWidth = charCount * 6 - 1
    local xStart = math.floor((scr_x - totalWidth) / 2)
    local yStart = math.max(3, math.floor((scr_y - 5) / 2))
    for i = 1, charCount do
        local ch = timeStr:sub(i, i)
        drawDigit(xStart + (i - 1) * 6, yStart, ch)
    end
end
local function getTimeStr()
    local t = textutils.formatTime(os.time(), true)
    local h, m = t:match("(%d+):(%d+)")
    if not h or not m then return "00:00" end
    return string.format("%02d:%02d", tonumber(h), tonumber(m))
end
local running = true
local function mainLoop()
    while running do
        term.setBackgroundColor(colors.purple)
        term.clear()
        drawTitle()
        term.setTextColor(colors.white)
        drawTimeString(getTimeStr())
        sleep(1)
    end
end
local function keyWatcher()
    os.pullEvent("key"); running = false
end
parallel.waitForAny(mainLoop, keyWatcher)
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.white)