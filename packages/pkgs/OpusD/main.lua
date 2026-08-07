local fs = fs
local tempDir = "temp"
local tempFile = fs.combine(tempDir, "sn.lua")
local flagFile = fs.combine(tempDir, "onb")
local startupFile = "startup.lua"
local optionsFile = "ninx/sys/boot/options.txt"
local lineToAdd = "Opus\tsys/boot/opus.lua"

-- Ensure temp folder exists
if not fs.exists(tempDir) then
    fs.makeDir(tempDir)
end

-- Save original startup.lua
if fs.exists(startupFile) then
    fs.move(startupFile, tempFile)
    print("Original startup.lua moved to " .. tempFile)
else
    print("No original startup.lua found.")
end

-- Create the onb flag for next boot
local f = fs.open(flagFile, "w")
if f then
    f.write("1")
    f.close()
    print("Flag file created: " .. flagFile)
else
    print("Failed to create flag file: " .. flagFile)
end

-- Append Opus entry to options.text
local f2 = fs.open(optionsFile, "a")
if f2 then
    f2.write(lineToAdd .. "\n")
    f2.close()
    print("Added line to " .. optionsFile)
else
    print("Could not open " .. optionsFile)
end

print("Ready to run the Opus installer.")
sleep(1)
fs.move("ninx/packages/Startup_Restore.lua", "ninx/packages/sr.lua")
print("Once in Opus open shell and run temp/sn.lua and, once in Ninx run sr.")
sleep(1.8)
shell.run("ninx/packages/Opus_Installer.lua")