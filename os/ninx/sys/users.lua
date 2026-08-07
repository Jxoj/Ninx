-- users.lua  Ninx shared user management library
-- Handles user DB, password hashing, permission checks
-- User DB: /ninx/.sys/users.json  (JSON array of user objects)
-- Root password: /ninx/.sys/root.hash

local users = {}

local USERS_FILE = "/ninx/.sys/users.json"
local ROOT_HASH  = "/ninx/.sys/root.hash"

-- ─── SHA-256 helper ──────────────────────────────────────────────────────────
local _sha = nil
local function sha256(s)
  if not _sha then
    local ok, m = pcall(dofile, "/ninx/.sys/utils/sha256.lua")
    _sha = (ok and m) or { hash = function(x) return tostring(#x) end }
  end
  return _sha.hash(tostring(s or ""))
end

-- ─── File helpers ─────────────────────────────────────────────────────────────
local function ensureDir(path)
  local d = fs.getDir(path)
  if d and d ~= "" and not fs.exists(d) then fs.makeDir(d) end
end

local function readJSON(path)
  if not fs.exists(path) then return nil end
  local fh = fs.open(path, "r")
  if not fh then return nil end
  local raw = fh.readAll(); fh.close()
  local ok, t = pcall(textutils.unserializeJSON, raw)
  if ok and t ~= nil then return t end
  return nil
end

local function writeJSON(path, data)
  ensureDir(path)
  local fh = fs.open(path, "w")
  if not fh then return false end
  fh.write(textutils.serializeJSON(data))
  fh.close()
  return true
end

-- ─── User DB ──────────────────────────────────────────────────────────────────
function users.load()
  local db = readJSON(USERS_FILE)
  if type(db) == "table" then return db end
  return {}
end

function users.save(db)
  return writeJSON(USERS_FILE, db)
end

function users.isFirstBoot()
  return not fs.exists(USERS_FILE) or #users.load() == 0
end

-- ─── Password hashing ────────────────────────────────────────────────────────
-- Passwords are stored as  sha256("ninx:" .. password)
-- Empty password → nil hash stored (no password required)
function users.hashPassword(plain)
  if not plain or plain == "" then return nil end
  return sha256("ninx:" .. plain)
end

-- ─── CRUD ─────────────────────────────────────────────────────────────────────
function users.create(name, plain, perms)
  local db = users.load()
  -- Check duplicate
  for _, u in ipairs(db) do
    if u.name == name then return false, "User already exists: " .. name end
  end
  local isFirst = (#db == 0)
  local defaultPerms = perms or {
    root        = isFirst,
    sudo        = isFirst,
    sys_files   = false,
    other_users = false,
  }
  local entry = {
    name  = name,
    hash  = users.hashPassword(plain),
    perms = defaultPerms,
    home  = "/ninx/usr/" .. name .. "/home",
  }
  table.insert(db, entry)
  -- Create home dir
  if not fs.exists(entry.home) then fs.makeDir(entry.home) end
  users.save(db)
  return true
end

function users.remove(name)
  local db = users.load()
  for i, u in ipairs(db) do
    if u.name == name then
      table.remove(db, i)
      users.save(db)
      return true
    end
  end
  return false, "User not found: " .. name
end

function users.get(name)
  for _, u in ipairs(users.load()) do
    if u.name == name then return u end
  end
  return nil
end

function users.update(name, changes)
  local db = users.load()
  for i, u in ipairs(db) do
    if u.name == name then
      for k, v in pairs(changes) do db[i][k] = v end
      users.save(db)
      return true
    end
  end
  return false, "User not found: " .. name
end

-- ─── Authentication ───────────────────────────────────────────────────────────
function users.authenticate(name, plain)
  local u = users.get(name)
  if not u then return false, "User not found" end
  if u.hash == nil then return true end   -- no password set
  return (users.hashPassword(plain) == u.hash), "Wrong password"
end

-- ─── Root password ────────────────────────────────────────────────────────────
function users.getRootHash()
  if not fs.exists(ROOT_HASH) then return nil end
  local fh = fs.open(ROOT_HASH, "r")
  if not fh then return nil end
  local h = fh.readAll(); fh.close()
  return h:match("^%s*(.-)%s*$")
end

function users.setRootPassword(plain)
  ensureDir(ROOT_HASH)
  local fh = fs.open(ROOT_HASH, "w")
  if not fh then return false end
  fh.write(users.hashPassword(plain) or "")
  fh.close()
  return true
end

function users.authenticateRoot(plain)
  local h = users.getRootHash()
  if not h or h == "" then return true end  -- no root password set
  return (users.hashPassword(plain) == h), "Wrong root password"
end

-- ─── Permission checks ────────────────────────────────────────────────────────
function users.hasPerm(name, perm)
  if name == "root" then return true end
  local u = users.get(name)
  if not u or not u.perms then return false end
  return u.perms[perm] == true
end

-- ─── Session globals ─────────────────────────────────────────────────────────
-- These are set by login.lua and su.lua:
--   _G.NINX_USER   = "alice"   (current username)
--   _G.NINX_ROOT   = true/false
--   _G.NINX_SUDO   = true/false (set momentarily by sudo.lua)
--   _G.NINX_CWD    = "/ninx/usr/alice/home"

function users.currentUser()
  return _G.NINX_USER or "guest"
end

function users.isRoot()
  return _G.NINX_ROOT == true
end

function users.isSudoActive()
  return _G.NINX_SUDO == true
end

-- Check whether the current session may perform an elevated action
function users.canSudo()
  if users.isRoot() then return true end
  return users.hasPerm(users.currentUser(), "sudo")
end

-- ─── Path permission guards ──────────────────────────────────────────────────
local SYS_PREFIX   = "/ninx/.sys"
local USERS_PREFIX = "/ninx/usr"

function users.isSystemPath(path)
  return path:sub(1, #SYS_PREFIX) == SYS_PREFIX
end

function users.isOtherUserPath(path)
  if path:sub(1, #USERS_PREFIX) ~= USERS_PREFIX then return false end
  local tail = path:sub(#USERS_PREFIX+2)
  local owner = tail:match("^([^/]+)")
  return owner and owner ~= users.currentUser()
end

-- Returns true if current session may write to path
function users.mayWrite(path, withSudo)
  if users.isRoot() then return true end
  local cur = users.currentUser()
  if users.isSystemPath(path) then
    return withSudo and users.hasPerm(cur, "sys_files")
  end
  if users.isOtherUserPath(path) then
    return withSudo and users.hasPerm(cur, "other_users")
  end
  return true
end

return users
