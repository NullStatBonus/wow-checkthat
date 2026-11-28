-- Strict JSON codec. No WoW globals. Canonical encoding: sorted keys, ASCII-only strings.
local _, ns = ...
local Json = {}
ns.Json = Json

local MAX_DEPTH = 40

local esc = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

local function utf8cp(s, i)
    local c = s:byte(i)
    if c < 0x80 then return c, 1 end
    if c >= 0xF0 then
        local a, b, d = s:byte(i + 1, i + 3)
        if not (a and b and d) then return 0xFFFD, 1 end
        return ((c % 8) * 262144) + ((a % 64) * 4096) + ((b % 64) * 64) + (d % 64), 4
    elseif c >= 0xE0 then
        local a, b = s:byte(i + 1, i + 2)
        if not (a and b) then return 0xFFFD, 1 end
        return ((c % 16) * 4096) + ((a % 64) * 64) + (b % 64), 3
    elseif c >= 0xC0 then
        local a = s:byte(i + 1)
        if not a then return 0xFFFD, 1 end
        return ((c % 32) * 64) + (a % 64), 2
    end
    return 0xFFFD, 1
end

local function encodeString(s)
    local out, i, n = { '"' }, 1, #s
    while i <= n do
        local c = s:byte(i)
        if c < 0x80 then
            local ch = string.char(c)
            if esc[ch] then out[#out + 1] = esc[ch]
            elseif c < 0x20 or c == 0x7F then out[#out + 1] = string.format("\\u%04x", c)
            else out[#out + 1] = ch end
            i = i + 1
        else
            local cp, len = utf8cp(s, i)
            if cp >= 0x10000 then
                cp = cp - 0x10000
                out[#out + 1] = string.format("\\u%04x\\u%04x", 0xD800 + math.floor(cp / 1024), 0xDC00 + cp % 1024)
            else
                out[#out + 1] = string.format("\\u%04x", cp)
            end
            i = i + len
        end
    end
    out[#out + 1] = '"'
    return table.concat(out)
end

local function isArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n == 0 then return true end
    for i = 1, n do if t[i] == nil then return false end end
    return true
end

local function enc(v, out, depth)
    if depth > MAX_DEPTH then error("too deep") end
    local tv = type(v)
    if tv == "string" then out[#out + 1] = encodeString(v)
    elseif tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then error("bad number") end
        if v == math.floor(v) and math.abs(v) < 1e15 then out[#out + 1] = string.format("%d", v)
        else out[#out + 1] = string.format("%.14g", v) end
    elseif tv == "boolean" then out[#out + 1] = v and "true" or "false"
    elseif tv == "table" then
        if isArray(v) then
            out[#out + 1] = "["
            for i = 1, #v do
                if i > 1 then out[#out + 1] = "," end
                enc(v[i], out, depth + 1)
            end
            out[#out + 1] = "]"
        else
            local keys = {}
            for k in pairs(v) do
                if type(k) ~= "string" then error("non-string key") end
                keys[#keys + 1] = k
            end
            table.sort(keys)
            out[#out + 1] = "{"
            for i, k in ipairs(keys) do
                if i > 1 then out[#out + 1] = "," end
                out[#out + 1] = encodeString(k) .. ":"
                enc(v[k], out, depth + 1)
            end
            out[#out + 1] = "}"
        end
    else error("cannot encode " .. tv) end
end

-- Returns string, or nil + error.
function Json.Encode(v)
    local out = {}
    local ok, err = pcall(enc, v, out, 0)
    if not ok then return nil, tostring(err) end
    return table.concat(out)
end

local function cpToUtf8(cp)
    if cp < 0x80 then return string.char(cp)
    elseif cp < 0x800 then return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
    elseif cp < 0x10000 then return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
    end
    return string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64, 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

local function fail(s, i, msg) error(("json: %s at %d"):format(msg, i), 0) end

local function skip(s, i)
    return s:find("[^ \t\r\n]", i) or #s + 1
end

local dec

local function decString(s, i)
    local out, j = {}, i + 1
    while true do
        local a = s:find('["\\]', j)
        if not a then fail(s, i, "unterminated string") end
        out[#out + 1] = s:sub(j, a - 1)
        if s:sub(a, a) == '"' then return table.concat(out), a + 1 end
        local e = s:sub(a + 1, a + 1)
        local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
        if map[e] then out[#out + 1] = map[e]; j = a + 2
        elseif e == "u" then
            local h = s:sub(a + 2, a + 5)
            if not h:match("^%x%x%x%x$") then fail(s, a, "bad escape") end
            local cp = tonumber(h, 16)
            j = a + 6
            if cp >= 0xD800 and cp < 0xDC00 then
                local h2 = s:match("^\\u(%x%x%x%x)", j)
                local lo = h2 and tonumber(h2, 16)
                if not lo or lo < 0xDC00 or lo > 0xDFFF then fail(s, a, "bad surrogate") end
                cp = 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00)
                j = j + 6
            end
            out[#out + 1] = cpToUtf8(cp)
        else fail(s, a, "bad escape") end
    end
end

dec = function(s, i, depth)
    if depth > MAX_DEPTH then fail(s, i, "too deep") end
    i = skip(s, i)
    local c = s:sub(i, i)
    if c == "{" then
        local t = {}
        i = skip(s, i + 1)
        if s:sub(i, i) == "}" then return t, i + 1 end
        while true do
            i = skip(s, i)
            if s:sub(i, i) ~= '"' then fail(s, i, "key expected") end
            local k
            k, i = decString(s, i)
            i = skip(s, i)
            if s:sub(i, i) ~= ":" then fail(s, i, "colon expected") end
            local v
            v, i = dec(s, i + 1, depth + 1)
            if t[k] ~= nil then fail(s, i, "duplicate key " .. k) end
            t[k] = v
            i = skip(s, i)
            local d = s:sub(i, i)
            if d == "}" then return t, i + 1 end
            if d ~= "," then fail(s, i, "comma expected") end
            i = i + 1
        end
    elseif c == "[" then
        local t, n = {}, 0
        i = skip(s, i + 1)
        if s:sub(i, i) == "]" then return t, i + 1 end
        while true do
            local v
            v, i = dec(s, i, depth + 1)
            n = n + 1
            t[n] = v
            i = skip(s, i)
            local d = s:sub(i, i)
            if d == "]" then return t, i + 1 end
            if d ~= "," then fail(s, i, "comma expected") end
            i = i + 1
        end
    elseif c == '"' then return decString(s, i)
    elseif s:sub(i, i + 3) == "true" then return true, i + 4
    elseif s:sub(i, i + 4) == "false" then return false, i + 5
    else
        local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
        if not num or num == "" then fail(s, i, "unexpected token (null is not allowed)") end
        local v = tonumber(num)
        if not v then fail(s, i, "bad number") end
        return v, i + #num
    end
end

-- Returns value, or nil + error.
function Json.Decode(s)
    if type(s) ~= "string" then return nil, "json: not a string" end
    local ok, v, i = pcall(dec, s, 1, 0)
    if not ok then return nil, tostring(v) end
    if skip(s, i) <= #s then return nil, "json: trailing data" end
    return v
end
