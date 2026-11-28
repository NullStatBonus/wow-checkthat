-- Lua 5.1 scanner. The game runs Lua 5.1; LuaJIT, which runs the tests, accepts more. This finds what differs:
--   goto and ::labels::            rejected by Lua 5.1
--   \x \z \u{ in a short string    Lua 5.1 reads them as the plain letter, LuaJIT reads an escape
--   LL, ULL and i number suffixes  Lua 5.1 rejects the number, LuaJIT reads a 64-bit or imaginary number
--   [[ inside a [[ ]] string or comment   Lua 5.1 rejects the nesting; use [=[ ]=] (LuaJIT accepts it)
-- Module: local L = dofile("tools/lua51_check.lua"); L.check(path) and L.checkText(text, name) give a list of
-- "file:line: message". Command line (exit 1 on a finding):
--   luajit tools/lua51_check.lua [--globals] FILE.lua|FILE.toc ...
-- --globals also fails when a file outside a Libs or Libraries folder reads io, os, jit, ffi, require, package, loadfile or
-- dofile as a global (read from the bytecode listing, luajit -bl, so a field such as x.os does not count).
local M = {}

M.BANNED = { "io", "os", "jit", "ffi", "require", "package", "loadfile", "dofile" }

local KEYWORD = {}
for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch("%a+") do KEYWORD[w] = true end

-- Tokens after which a statement can start (or that end an expression, so the next word begins a statement).
local ENDS = {}
for w in ("then do else end repeat true false nil string number ) ] } ... ; ::"):gmatch("%S+") do ENDS[w] = true end

function M.checkText(text, name)
    name = name or "?"
    text = text:gsub("\r\n", "\n"):gsub("\n\r", "\n"):gsub("\r", "\n") -- Lua counts \r\n, \n\r and a lone \r as one line end
    local out = {}
    local line, pos, n = 1, 1, #text
    local prev -- the last token: a name, keyword, or symbol
    local function add(msg) out[#out + 1] = ("%s:%d: %s"):format(name, line, msg) end
    local function lines(s) for _ in s:gmatch("\n") do line = line + 1 end end
    -- A long bracket [==[ ... ]==] starting at p. Returns the position after it, or nil when p is not one.
    local function longEnd(p)
        local eq = text:match("^%[(=*)%[", p)
        if not eq then return nil end
        local _, e = text:find("]" .. eq .. "]", p + #eq + 2, true)
        return (e or n) + 1
    end
    if text:sub(1, 1) == "#" then pos = (text:find("\n", 1, true) or n) end -- a first line starting with # is skipped
    -- Lua 5.1 rejects a [[ inside a level-0 long string or comment. a..b is the span of the whole bracket.
    local function nested(a, b)
        if not text:match("^%[%[", a) and not text:match("^%-%-%[%[", a) then return end
        local from = text:match("^%-%-", a) and a + 4 or a + 2
        local at = text:find("[[", from, true)
        if at and at < b then
            local save = line
            for _ in text:sub(a, at - 1):gmatch("\n") do line = line + 1 end
            add("Lua 5.1 rejects [[ inside a [[ ]] string or comment (nesting is deprecated). Use [=[ ]=] for the outer one.")
            line = save
        end
    end
    while pos <= n do
        local c = text:sub(pos, pos)
        if c == "\n" then line = line + 1; pos = pos + 1
        elseif c:match("%s") then pos = pos + 1
        elseif text:sub(pos, pos + 1) == "--" then
            local e = longEnd(pos + 2)
            if e then nested(pos, e - 2); lines(text:sub(pos, e - 1)); pos = e
            else pos = (text:find("\n", pos, true) or n + 1) end
        elseif c == "[" and longEnd(pos) then
            local e = longEnd(pos); nested(pos, e - 2); lines(text:sub(pos, e - 1)); pos = e; prev = "string"
        elseif c == '"' or c == "'" then
            local p = pos + 1
            while p <= n do
                local d = text:sub(p, p)
                if d == "\\" then
                    local nx = text:sub(p + 1, p + 1)
                    if nx == "x" then add("Lua 5.1 reads \\x as the letter x, LuaJIT reads a hex byte. Use \\ddd for this byte.")
                    elseif nx == "z" then add("Lua 5.1 reads \\z as the letter z, LuaJIT skips the white space after it. Write the string on one line.")
                    elseif nx == "u" and text:sub(p + 2, p + 2) == "{" then add("Lua 5.1 reads \\u as the letter u, LuaJIT reads a code point. Use \\ddd bytes for this character.") end
                    if nx == "\n" then line = line + 1 end
                    p = p + 2
                elseif d == c or d == "\n" then break
                else p = p + 1 end
            end
            pos = p + 1; prev = "string"
        elseif c:match("[%a_]") then
            local w = text:match("^[%w_]+", pos)
            if w == "goto" then
                local nxt = text:match("^%s*([%a_][%w_]*)", pos + 4)
                local starts = prev == nil or ENDS[prev] or (prev:match("^[%a_]") and not KEYWORD[prev] and prev ~= "goto")
                if nxt and not KEYWORD[nxt] and starts then
                    add("Lua 5.1 rejects goto. Use a flag, break or a function with return instead.")
                end
            end
            pos = pos + #w; prev = w
        elseif c:match("%d") or (c == "." and text:sub(pos + 1, pos + 1):match("%d")) then
            -- the whole numeral: mantissa, exponent, then every name character after it (LL, i, _000, b1010)
            local num = text:match("^0[xX]%x*%.?%x*", pos)
            local hexfloat = false
            if num then
                local ex = text:match("^[pP][+-]?%d+", pos + #num)
                hexfloat = ex ~= nil or num:find(".", 1, true) ~= nil
                num = num .. (ex or "")
            else
                num = text:match("^%d*%.?%d*", pos)
                num = num .. (text:match("^[eE][+-]?%d+", pos + #num) or "")
            end
            local suffix = text:match("^[%w_]*", pos + #num)
            local low = suffix:lower()
            if hexfloat then add("Lua 5.1 rejects a hex number with a fraction or p exponent (" .. num .. suffix .. "). Write a decimal number.")
            elseif low == "ll" or low == "ull" then add("Lua 5.1 rejects the number suffix " .. suffix .. ". Use a plain number.")
            elseif low == "i" then add("Lua 5.1 rejects the number suffix " .. suffix .. ". Imaginary numbers do not exist there.")
            elseif num == "0" and low:match("^b[01]+$") then add("Lua 5.1 rejects a binary number (" .. num .. suffix .. "). Write a decimal or hex number.")
            elseif suffix:find("_", 1, true) then add("Lua 5.1 rejects _ inside a number (" .. num .. suffix .. "). Remove the underscore.") end
            pos = pos + #num + #suffix; prev = "number"
        elseif text:sub(pos, pos + 1) == "::" then
            add("Lua 5.1 rejects :: (a goto label). Remove the label.")
            local label = text:match("^::%s*[%a_][%w_]*%s*::", pos)
            pos = pos + (label and #label or 2); prev = "::"
        elseif text:sub(pos, pos + 2) == "..." then pos = pos + 3; prev = "..."
        elseif text:sub(pos, pos + 1) == ".." then pos = pos + 2; prev = ".."
        else pos = pos + 1; prev = c end
    end
    return out
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

function M.check(path)
    local text = readFile(path)
    if not text then return { path .. ":0: cannot read the file" } end
    return M.checkText(text, path)
end

-- Banned globals a file reads, as "file: reads the global name" (needs luajit on the path).
function M.bannedGlobals(path)
    local out, seen = {}, {}
    local p = io.popen("luajit -bl '" .. path:gsub("'", "'\\''") .. "' 2>&1")
    if not p then return { path .. ": cannot list the bytecode" } end
    local banned = {}
    for _, b in ipairs(M.BANNED) do banned[b] = true end
    local gReg -- the register that just received _G, so the next TGETS on it is _G.name or _G["name"]
    for l in p:lines() do
        local g = l:match('GGET%s.-;%s*"([^"]+)"')
        if not g and gReg then
            local src, key = l:match('TGETS%s+%d+%s+(%d+)%s+%d+%s*;%s*"([^"]+)"')
            if src == gReg then g = key end
        end
        gReg = nil
        if l:match('GGET%s+%d+%s+%d+%s*;%s*"_G"') then gReg = l:match("GGET%s+(%d+)") end
        if g and banned[g] and not seen[g] then seen[g] = true; out[#out + 1] = ("%s: reads the global %s. The game does not give addons this global."):format(path, g) end
        if l:find("luajit:", 1, true) then out[#out + 1] = l end
    end
    p:close()
    return out
end

local function main(args)
    local here = arg[0]:match("^(.*)/tools/[^/]*$") or "."
    local globals = false
    local files, base = {}, {} -- base: the addon folder of a file, so library folders are matched below it
    for _, a in ipairs(args) do
        if a == "--globals" then globals = true
        elseif a:match("%.toc$") then
            local H = select(5, dofile(here .. "/tests/harness.lua")())
            local list, err = H.tocFiles(a)
            if not list then io.stderr:write(a, ": ", err, "\n"); os.exit(1) end
            local dir = a:match("^(.*)/[^/]+$") or "."
            for _, f in ipairs(list) do files[#files + 1] = f; base[f] = dir end
        else files[#files + 1] = a; base[a] = a:match("^(.*)/[^/]+$") or "." end
    end
    local bad = 0
    for _, f in ipairs(files) do
        local found = M.check(f)
        local below = "/" .. f:sub(#base[f] + 2):lower()
        if globals and not below:find("/libs/", 1, true) and not below:find("/libraries/", 1, true) then
            for _, g in ipairs(M.bannedGlobals(f)) do found[#found + 1] = g end
        end
        for _, m in ipairs(found) do print(m); bad = bad + 1 end
    end
    os.exit(bad == 0 and 0 or 1)
end

if arg and arg[0] and arg[0]:find("lua51_check%.lua$") then main(arg) end
return M
