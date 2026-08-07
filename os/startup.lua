term.clear()
term.setCursorPos(1,1)
local shell = shell
local term = term
local keys = keys
local colors = colors

local function runKernel()
  pcall(function() shell.run("/ninx/.sys/boot/kernel.lua") end)
end

local function monitorCtrlB()
  local ctrlDown = false
  while true do
    local ev, k = os.pullEvent()
    if ev == "key" then
      if k == keys.leftCtrl or k == keys.rightCtrl then
        ctrlDown = true
      elseif k == keys.b and ctrlDown then
        term.setTextColor(colors.white)
        pcall(function() shell.run("/ninx/.sys/bios.lua") end)
        term.setTextColor(colors.white)
      end
    elseif ev == "key_up" then
      if k == keys.leftCtrl or k == keys.rightCtrl then
        ctrlDown = false
      end
    end
  end
end

runKernel()


print("Kernel Failed")
sleep(1)
print("")
print("Starting CraftOS..")
sleep(1)
term.setCursorPos(1,1)
term.clear()