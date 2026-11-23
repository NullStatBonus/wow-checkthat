local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
-- Every player-facing sentence is L["The whole English sentence"]: no concatenation, no variable keys.
local function files()
    local out = {}
    local p = io.popen("find CheckThat -name '*.lua' -not -path 'CheckThat/Libs/*' | sort")
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end
test("every L[...] key is a complete English literal", function()
    local count = 0
    for _, path in ipairs(files()) do
        local f = io.open(path); local src = f:read("*a"); f:close()
        local n = 0
        for line in (src .. "\n"):gmatch("(.-)\n") do
            n = n + 1
            if not line:match("^%s*%-%-") then
                local from = 1
                while true do
                    local a, b = line:find("L%[", from)
                    if not a then break end
                    if a == 1 or not line:sub(a - 1, a - 1):match("[%w_]") then
                        count = count + 1
                        T.ok(line:sub(b + 1, b + 1) == '"', ("%s:%d: L[] needs a string literal"):format(path, n))
                        local close = line:find('"%]', b + 2)
                        T.ok(close, ("%s:%d: L[] literal is not closed on its line"):format(path, n))
                    end
                    from = b + 1
                end
                T.ok(not line:find('L%["[^"]*"%s*%.%.'), ("%s:%d: L[] key is concatenated"):format(path, n))
            end
        end
    end
    T.ok(count > 40, "found the keys")
end)
test("chat text has no raw pipe except color codes", function()
    for _, path in ipairs(files()) do
        local f = io.open(path); local src = f:read("*a"); f:close()
        for key in src:gmatch('L%["([^"]*)"%]') do
            local stripped = key:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", "")
            T.ok(not stripped:find("|", 1, true), path .. ": raw | in " .. key)
        end
    end
end)
test("enUS returns the key, never errors on a missing entry", function()
    T.eq(ns.L["Some sentence"], "Some sentence")
end)
finish()
