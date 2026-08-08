local roulette = io.open("roulette.lua", "r")
local content = roulette:read("*a")
roulette:close()

local ost = io.open("ost.dfpwm", "rb")
local binary = ost:read("*a")
ost:close()

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local encoded = {}
for i = 1, #binary, 3 do
    local b1, b2, b3 = string.byte(binary, i, i + 2)
    b2, b3 = b2 or 0, b3 or 0
    local n = b1 * 65536 + b2 * 256 + b3
    encoded[#encoded + 1] = b64chars:sub(n // 262144 + 1, n // 262144 + 1)
    encoded[#encoded + 1] = b64chars:sub((n // 4096) % 64 + 1, (n // 4096) % 64 + 1)
    encoded[#encoded + 1] = (i + 1 <= #binary)
        and b64chars:sub((n // 64) % 64 + 1, (n // 64) % 64 + 1) or "="
    encoded[#encoded + 1] = (i + 2 <= #binary)
        and b64chars:sub(n % 64 + 1, n % 64 + 1) or "="
end
local b64string = table.concat(encoded)

local decoder = [=[
local b="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local s="]=] .. b64string .. [=["
local t={}for i=1,#b do t[b:sub(i,i)]=i-1 end
local d={}for i=1,#s,4 do
local a=t[s:sub(i,i)]or 0
local c=t[s:sub(i+1,i+1)]or 0
local e=t[s:sub(i+2,i+2)]
local g=t[s:sub(i+3,i+3)]
local n=a*262144+c*4096+(e or 0)*64+(g or 0)
d[#d+1]=string.char(math.floor(n/65536))
if e then d[#d+1]=string.char(math.floor((n%65536)/256))end
if g then d[#d+1]=string.char(n%256)end
end local f=table.concat(d)
]=]

local target = 'local f = fs.open("ost.dfpwm", "rb").readAll()'
local pos = content:find(target, 1, true)
if not pos then
    error("Could not find target line in roulette.lua")
end
content = content:sub(1, pos - 1) .. decoder .. content:sub(pos + #target)

local out = io.open("buccshot.lua", "w")
out:write(content)
out:close()

print(string.format("Generated buccshot.lua (%.1f KB)", #content / 1024))
