-- zip.lua  Pure-Lua STORE-only ZIP extractor for ComputerCraft
-- Packages MUST be created with ZIP_STORED (no compression)
-- build_pkg.py uses zipfile.ZIP_STORED automatically

local zip = {}

local function byte4(s, pos)
  local a,b,c,d = string.byte(s,pos), string.byte(s,pos+1),
                  string.byte(s,pos+2), string.byte(s,pos+3)
  if not (a and b and c and d) then return 0 end
  return a + b*256 + c*65536 + d*16777216
end

local function byte2(s, pos)
  local a,b = string.byte(s,pos), string.byte(s,pos+1)
  if not (a and b) then return 0 end
  return a + b*256
end

-- Returns: ok (bool), result (table of extracted paths or error string)
function zip.extract(data, destDir)
  if type(data) ~= "string" or #data < 4 then
    return false, "Invalid or empty ZIP data"
  end
  destDir = destDir:gsub("/$","")
  local extracted = {}
  local pos = 1
  local dataLen = #data

  while pos <= dataLen - 3 do
    local sig = byte4(data, pos)

    if sig == 0x04034b50 then
      -- Local file header
      local compMethod = byte2(data, pos+8)
      local compSize   = byte4(data, pos+18)
      local fnLen      = byte2(data, pos+26)
      local extraLen   = byte2(data, pos+28)

      if pos+29+fnLen > dataLen then break end
      local filename   = data:sub(pos+30, pos+29+fnLen)
      local dataStart  = pos + 30 + fnLen + extraLen
      local dataEnd    = dataStart + compSize - 1

      if compMethod ~= 0 then
        return false, "Package uses DEFLATE compression. Please rebuild with ZIP_STORED (build_pkg.py does this automatically)."
      end

      -- Skip directory entries (end with /)
      if filename:sub(-1) ~= "/" and filename ~= "" then
        local destPath = destDir .. "/" .. filename
        -- Normalise path separators
        destPath = destPath:gsub("\\","/"):gsub("//+","/")

        -- Create parent directories
        local dir = destPath:match("^(.*)/[^/]+$")
        if dir and dir ~= "" and not fs.exists(dir) then
          fs.makeDir(dir)
        end

        local fileData = (compSize > 0) and data:sub(dataStart, dataEnd) or ""

        -- Try binary write first, fall back to text
        local written = false
        local fh = fs.open(destPath, "wb")
        if fh then
          fh.write(fileData)
          fh.close()
          written = true
        else
          fh = fs.open(destPath, "w")
          if fh then
            fh.write(fileData)
            fh.close()
            written = true
          end
        end

        if written then
          table.insert(extracted, destPath)
        else
          return false, "Cannot write file: " .. destPath
        end
      elseif filename:sub(-1) == "/" then
        local dirPath = destDir .. "/" .. filename:sub(1,-2)
        if not fs.exists(dirPath) then fs.makeDir(dirPath) end
      end

      pos = dataStart + compSize
      if pos < 1 then pos = 1 end

    elseif sig == 0x02014b50 or sig == 0x06054b50 then
      -- Central directory or EOCD - we're done
      break
    else
      pos = pos + 1
    end
  end

  if #extracted == 0 then
    return false, "No files were extracted (check ZIP integrity or method)"
  end
  return true, extracted
end

return zip
