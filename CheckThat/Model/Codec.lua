-- Import/export strings: "!CT1!<adler32 hex>!<base64 of raw deflate of canonical JSON>".
local _, ns = ...
local Codec = {}
ns.Codec = Codec

Codec.PREFIX = "!CT1!"
Codec.LIMITS = { encoded = 120000, inflated = 2000000 }

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64idx = {}
for i = 1, 64 do b64idx[B64:byte(i)] = i - 1 end

local function b64enc(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2, c3, c4 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function b64dec(s)
    s = s:gsub("%s", "")
    if #s % 4 ~= 0 or s:find("[^%w+/=]") or s:find("=[^=]") then return nil end
    local out = {}
    for i = 1, #s, 4 do
        local a, b, c, d = s:byte(i, i + 3)
        local pc, pd = c == 61, d == 61
        if a == 61 or b == 61 or (pc and not pd) then return nil end
        local n = b64idx[a] * 262144 + b64idx[b] * 4096 + (pc and 0 or b64idx[c]) * 64 + (pd and 0 or b64idx[d])
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if not pc then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if not pd then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end
Codec.b64enc, Codec.b64dec = b64enc, b64dec

local function deflate() return ns.LibDeflate or (LibStub and LibStub("LibDeflate")) end

-- Encode a table. Returns string, or nil + error.
function Codec.Encode(tbl)
    local LD = deflate()
    if not LD then return nil, "LibDeflate missing" end
    local json, err = ns.Json.Encode(tbl)
    if not json then return nil, err end
    local packed = LD:CompressDeflate(json, { level = 9 })
    return Codec.PREFIX .. string.format("%08x", LD:Adler32(json)) .. "!" .. b64enc(packed)
end

-- Decode a pasted string. Returns table, or nil + error. Never loads code; never partially applies.
function Codec.Decode(str)
    local LD = deflate()
    if not LD then return nil, "LibDeflate missing" end
    if type(str) ~= "string" then return nil, "not a string" end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    if #str > Codec.LIMITS.encoded then return nil, "string too large" end
    local ver, sum, body = str:match("^!CT(%d+)!(%x%x%x%x%x%x%x%x)!(.+)$")
    if not ver then
        if str:match("^!CT") then return nil, "unknown or malformed CT string version" end
        return nil, "not a CT string"
    end
    if ver ~= "1" then return nil, "unsupported CT version " .. ver end
    local packed = b64dec(body)
    if not packed then return nil, "bad base64" end
    local json = LD:DecompressDeflate(packed)
    if not json then return nil, "bad compressed data" end
    if #json > Codec.LIMITS.inflated then return nil, "decoded data too large" end
    if string.format("%08x", LD:Adler32(json)) ~= sum:lower() then return nil, "checksum mismatch" end
    local tbl, err = ns.Json.Decode(json)
    if not tbl then return nil, err end
    return tbl, nil, sum:lower()
end
