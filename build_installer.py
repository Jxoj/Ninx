import os

files_to_install = []

# Walk through the 'os' directory
for root, dirs, files in os.walk('os'):
    for file in files:
        filepath = os.path.join(root, file)
        
        # Determine install path
        parts = filepath.split(os.sep)
        
        if len(parts) >= 3 and parts[0] == 'os' and parts[1] == 'ninx' and parts[2] == 'sys':
            # Map os/ninx/sys/... to ninx/.sys/...
            install_path = 'ninx/.sys/' + '/'.join(parts[3:])
        elif len(parts) == 2 and parts[0] == 'os':
            # Map os/startup.lua to startup.lua
            install_path = parts[1]
        else:
            # Map os/ninx/other/... to ninx/other/...
            install_path = '/'.join(parts[1:])
            
        files_to_install.append({
            'source': filepath,
            'dest': install_path
        })

lua_script = """-- Ninx Installer
term.setBackgroundColor(colors.black)
term.setTextColor(colors.orange)
term.clear()
term.setCursorPos(1, 1)

print("==============================")
print("       Ninx Installer         ")
print("==============================")
print("Downloading files...")
print("")

local files = {
"""

for item in files_to_install:
    source = item['source'].replace('\\', '/')
    dest = item['dest'].replace('\\', '/')
    url = f"https://raw.githubusercontent.com/Jxoj/Ninx/main/{source}"
    lua_script += f'  {{ url = "{url}", dest = "{dest}" }},\n'

lua_script += """}

local function getFile(url, dest)
    write("Downloading " .. dest .. "... ")
    local res = http.get(url)
    if res then
        local content = res.readAll()
        res.close()
        
        -- Create directories if they don't exist
        local dir = fs.getDir(dest)
        if not fs.exists(dir) then
            fs.makeDir(dir)
        end
        
        local f = fs.open(dest, "w")
        if f then
            f.write(content)
            f.close()
            print("OK")
            return true
        else
            print("Failed to write")
            return false
        end
    else
        print("Failed to download")
        return false
    end
end

local success = true
for _, file in ipairs(files) do
    if not getFile(file.url, file.dest) then
        success = false
    end
end

print("")
if success then
    print("Installation complete! Rebooting in 3 seconds...")
    os.sleep(3)
    os.reboot()
else
    print("Installation finished with errors.")
end
"""

with open('install', 'w', encoding='utf-8') as f:
    f.write(lua_script)

print("Generated 'install' script successfully.")
