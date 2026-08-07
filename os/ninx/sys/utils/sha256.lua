-- sha256.lua  Pure-Lua SHA-256 for ComputerCraft
-- Returns lowercase 64-char hex string
-- Compatible with CC Lua 5.1 (uses bit library)

local sha256 = {}

local _bit = bit or bit32 or {}
local function _band(a,b)  if _bit.band  then return _bit.band(a,b)  else return a & b end end
local function _bxor(a,b)  if _bit.bxor  then return _bit.bxor(a,b)  else return a ~ b end end
local function _bnot(a)    if _bit.bnot  then return _bit.bnot(a)    else return ~a     end end
local function _bor(a,b)   if _bit.bor   then return _bit.bor(a,b)   else return a | b  end end
local function _rsh(a,n)   if _bit.rshift then return _bit.rshift(a,n) else return a >> n end end
local function _lsh(a,n)   if _bit.lshift then return _bit.lshift(a,n) else return a << n end end

local M = 2^32
local function u32(n) return n % M end

local function rrot(x, n)
  x = u32(x)
  return _bor(u32(_rsh(x, n)), u32(_lsh(x, 32-n)))
end

local K = {
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

local IH = {
  0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
  0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19,
}

local function compress(h, block)
  local w = {}
  for i=1,16 do
    local o = (i-1)*4
    w[i] = string.byte(block,o+1)*0x1000000
          + string.byte(block,o+2)*0x10000
          + string.byte(block,o+3)*0x100
          + string.byte(block,o+4)
  end
  for i=17,64 do
    local s0 = _bxor(rrot(w[i-15],7),  _bxor(rrot(w[i-15],18), _rsh(w[i-15],3)))
    local s1 = _bxor(rrot(w[i-2], 17), _bxor(rrot(w[i-2], 19), _rsh(w[i-2], 10)))
    w[i] = u32(w[i-16] + u32(s0) + w[i-7] + u32(s1))
  end
  local a,b,c,d,e,f,g,hv = h[1],h[2],h[3],h[4],h[5],h[6],h[7],h[8]
  for i=1,64 do
    local S1   = _bxor(rrot(e,6), _bxor(rrot(e,11), rrot(e,25)))
    local ch   = _bxor(_band(e,f), _band(_bnot(e),g))
    local t1   = u32(hv + u32(S1) + u32(ch) + K[i] + w[i])
    local S0   = _bxor(rrot(a,2), _bxor(rrot(a,13), rrot(a,22)))
    local maj  = _bxor(_band(a,b), _bxor(_band(a,c), _band(b,c)))
    local t2   = u32(u32(S0) + u32(maj))
    hv=g; g=f; f=e; e=u32(d+t1); d=c; c=b; b=a; a=u32(t1+t2)
  end
  h[1]=u32(h[1]+a); h[2]=u32(h[2]+b); h[3]=u32(h[3]+c); h[4]=u32(h[4]+d)
  h[5]=u32(h[5]+e); h[6]=u32(h[6]+f); h[7]=u32(h[7]+g); h[8]=u32(h[8]+hv)
end

function sha256.hash(msg)
  msg = tostring(msg or "")
  local len = #msg
  -- Pre-processing
  msg = msg .. "\128"
  local pad = (56 - #msg % 64) % 64
  msg = msg .. string.rep("\0", pad)
  -- Length in bits as 64-bit big-endian (we only handle 32-bit length)
  local bithi = math.floor(len / 0x20000000)  -- len*8 high 32 bits
  local bitlo = (len * 8) % M
  msg = msg .. string.char(
    math.floor(bithi/0x1000000)%256, math.floor(bithi/0x10000)%256,
    math.floor(bithi/0x100)%256,    bithi%256,
    math.floor(bitlo/0x1000000)%256,math.floor(bitlo/0x10000)%256,
    math.floor(bitlo/0x100)%256,    bitlo%256
  )
  local h = {table.unpack(IH)}
  for i=1,#msg,64 do compress(h, msg:sub(i,i+63)) end
  local r=""
  for _,v in ipairs(h) do r = r .. string.format("%08x",v) end
  return r
end

return sha256
