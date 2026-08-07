
local term, fs, shell, textutils, http, colors, keys, disk, peripheral = term, fs, shell, textutils, http, colors, keys, disk, peripheral

local function status(tag, color, msg)
  term.setTextColor(colors.white)
  write("["); term.setTextColor(color); write(tag); term.setTextColor(colors.white); write("] ")
  term.setTextColor(colors.white); print(msg or "")
end

local device_registry = { printers={}, drives={}, speakers={}, modems={}, disks={}, monitors={}, turtles={}, network={} }
local counts = { printer=0, drive=0, speaker=0, modem=0, monitor=0, turtle=0, disk=0 }

local function compareVersion(a, b)
  if not a then a = "0" end; if not b then b = "0" end
  local function parts(s) local t={}; for n in s:gmatch("%d+") do t[#t+1]=tonumber(n) end; return t end
  local va, vb = parts(a), parts(b)
  for i=1,math.max(#va,#vb) do local x=va[i] or 0; local y=vb[i] or 0; if x<y then return -1 elseif x>y then return 1 end end
  return 0
end
local function readLocalVersion(path) if not fs.exists(path) then return nil end local f=fs.open(path,"r"); if not f then return nil end local s=f.readAll(); f.close(); return s and s:match("^%s*(.-)%s*$") or nil end
local function fetchRemoteVersion(url) if not http then return nil,"http disabled" end local r=http.get(url); if not r then return nil,"http.get failed" end local b=r.readAll(); r.close(); if not b then return nil,"empty" end return b:match("^%s*(.-)%s*$") end

local DISK_REG = "/ninx/.sys/disk_registry.lua"
local DEV_REG  = "/ninx/.sys/device_registery.lua"
local function ensureDirFor(path) local dir=fs.getDir(path); if dir~="" and not fs.exists(dir) then fs.makeDir(dir) end end
local function loadDiskRegistry() if not fs.exists(DISK_REG) then return {} end local ok,t=pcall(dofile, DISK_REG); if ok and type(t)=="table" then return t end return {} end
local function saveDiskRegistry(tbl) ensureDirFor(DISK_REG); local f=fs.open(DISK_REG,"w"); if not f then return false end f.write("return "..textutils.serialize(tbl)); f.close(); return true end
local function writeDeviceRegistry() ensureDirFor(DEV_REG); local f=fs.open(DEV_REG,"w"); if not f then return false end f.write("return "..textutils.serialize(device_registry)); f.close(); return true end
local function findAliasForMount(tbl,m) for a,p in pairs(tbl) do if p==m then return a end end end
local function nextAlias(tbl) local i=1 while true do local n="d"..i if not tbl[n] then return n end i=i+1 end end
local function registerMount(m) if not m or m=="" then return nil end local reg=loadDiskRegistry(); local e=findAliasForMount(reg,m); if e then return e end local a=nextAlias(reg); reg[a]=m; saveDiskRegistry(reg); return a end

local function scanDisks(limit)
  limit = limit or 10
  local found = {}
  if peripheral and peripheral.getNames then
    for _, name in ipairs(peripheral.getNames()) do
      if #found >= limit then break end
      local ptype = peripheral.getType(name) or ""
      local lower = ptype:lower()
      if lower:match("drive") or lower:match("disk") or name:lower():match("drive") or name:lower():match("disk") then
        local has, mountPath, label = false, nil, nil
        if disk and disk.hasData then local ok,res=pcall(function() return disk.hasData(name) end); if ok and res then has=true; local ok2,mp=pcall(function() return disk.getMountPath(name) end); if ok2 then mountPath=mp end end end
        local okWrap, drv = pcall(peripheral.wrap, name); if okWrap and drv and drv.getDiskLabel then local okL, lab=pcall(function() return drv.getDiskLabel() end); if okL then label=lab end end
        if not mountPath then for i=1,16 do local try=(i==1) and "disk" or ("disk"..i); if fs.exists("/"..try) then mountPath=try; has=true; break end end end
        if has then counts.drive=counts.drive+1; local ddId="dd"..counts.drive; device_registry.drives[ddId]=name; counts.disk=counts.disk+1; local dId="d"..counts.disk; device_registry.disks[dId]={ drive=name, mount=mountPath, label=label }
          table.insert(found,{name=name,type=ptype,mount=mountPath,alias=registerMount(mountPath),label=label, dd=ddId, d=dId})
          status("Success", colors.green, ("Disk %s: drive=%s mount=%s label=%s alias=%s"):format(dId, name, tostring(mountPath), tostring(label), tostring(found[#found].alias)))
        end
      end
    end
  end
  if #found==0 then for i=1,limit do local try=(i==1) and "disk" or ("disk"..i); if fs.exists("/"..try) then counts.disk=counts.disk+1; local dId="d"..counts.disk; device_registry.disks[dId]={ drive=try, mount=try }; table.insert(found,{name=try,type="mount",mount=try,alias=registerMount(try), d=dId}); status("Success", colors.green, ("Disk %s: mount=%s alias=%s"):format(dId, try, tostring(found[#found].alias))) end end end
  return found
end

local function deviceDiscovery()
  local ok, per=pcall(function() return peripheral and peripheral.getNames and peripheral.getNames() or {} end); if not ok then return end
  for _, name in ipairs(per) do
    local ptype = peripheral.getType(name)
    if ptype=="printer" then counts.printer=counts.printer+1; local id="p"..counts.printer; device_registry.printers[id]=name; status("Success", colors.green, ("Printer %s: %s"):format(id,name))
    elseif ptype=="drive" then 
    elseif ptype=="speaker" then counts.speaker=counts.speaker+1; local id="s"..counts.speaker; device_registry.speakers[id]=name; status("Success", colors.green, ("Speaker %s: %s"):format(id,name))
    elseif ptype=="modem" then counts.modem=counts.modem+1; local id="m"..counts.modem; device_registry.modems[id]=name; local okW,m=pcall(peripheral.wrap,name); if okW and m and m.open then pcall(function() m.open(1) end) end; status("Success", colors.green, ("Modem %s: %s"):format(id,name))
    elseif ptype=="monitor" then counts.monitor=counts.monitor+1; local id="mo"..counts.monitor; device_registry.monitors[id]=name; status("Success", colors.green, ("Monitor %s: %s"):format(id,name))
    elseif ptype=="turtle" then counts.turtle=counts.turtle+1; local id="t"..counts.turtle; device_registry.turtles[id]=name; status("Success", colors.green, ("Turtle %s: %s"):format(id,name)) end
  end
  if rednet then local side=nil; for _,n in ipairs(per) do if peripheral.getType(n)=="modem" then side=n; break end end; if side then if pcall(function() return rednet.open(side) end) then pcall(function() rednet.broadcast("NINX_REQUEST_PERIPHERALS","ninx_discover") end); local start=os.clock(); local timeout=2; while os.clock()-start<timeout do local id,msg,proto=rednet.receive("ninx_discover", timeout-(os.clock()-start)); if not id then break end; device_registry.network[tostring(id)]=msg; status("Success", colors.green, ("Network host %s discovered"):format(tostring(id))) end; pcall(function() rednet.close(side) end) end end end
end

local biosRequested = false
local function watcher()
  while true do
    local ev, p1 = os.pullEvent()
    if ev == "char" and (p1 == "b" or p1 == "B") then
      biosRequested = true
      return
    elseif ev == "key" and p1 == keys.b then
      biosRequested = true
      return
    end
  end
end
local function mainFlow()
  term.setTextColor(colors.white); print("Ninx kernel starting..."); sleep(0.2); status("Info", colors.yellow, "Checking for updates..."); sleep(0.2)
  local remoteURL = "https://jxoj.github.io/Ninx/version.txt"; local localVersionPath = "/ninx/.sys/v"; local remoteVers = fetchRemoteVersion(remoteURL)
  if remoteVers then
    local localVers = readLocalVersion(localVersionPath) or "0"
    if compareVersion(localVers, remoteVers) < 0 then status("Info", colors.yellow, "Remote newer. Launching installer..."); sleep(0.5); local ok=pcall(function() shell.run("wget","run","https://jxoj.github.io/Ninx/install","-u") end); if ok then return end else status("Success", colors.green, "System up-to-date ("..(localVers or "0")..")") end
  else
    status("Error", colors.red, "Could not fetch remote version")
  end
  if biosRequested then return end
  status("Info", colors.yellow, "Scanning disks..."); sleep(0.2); local disks=scanDisks(10); if #disks>0 then status("Success", colors.green, "Registered "..tostring(#disks).." disk mount(s)") else status("Info", colors.yellow, "No disks detected") end; sleep(0.3)
  if biosRequested then return end
  status("Info", colors.yellow, "Discovering devices and network..."); pcall(deviceDiscovery); status("Success", colors.green, "Discovery complete"); sleep(0.2)
  if biosRequested then return end
  if writeDeviceRegistry() then status("Success", colors.green, "Device registry written to "..DEV_REG) else status("Error", colors.red, "Failed to write device registry") end
end

if parallel and parallel.waitForAny then
  parallel.waitForAny(mainFlow, watcher)
else
  
  mainFlow()
end

if biosRequested then
  status("Info", colors.yellow, "Opening BIOS...")
  pcall(function() shell.run("/ninx/.sys/bios.lua") end)
  return
end

status("Info", colors.yellow, "Booting bootmenu..."); sleep(0.5); pcall(function() shell.run("/ninx/.sys/boot/menu/bootmenu.lua") end)