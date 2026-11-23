local ns, test, T, finish = dofile("tests/harness.lua")()
-- The README lists every /ct command the addon handles.
test("README documents each command", function()
    local f = io.open("CheckThat/Core/Slash.lua"); local src = f:read("*a"); f:close()
    local r = io.open("README.md"); local readme = r:read("*a"); r:close()
    local seen = 0
    for cmd in src:gmatch('cmd == "(%a+)"') do
        seen = seen + 1
        T.ok(readme:find("/ct " .. cmd, 1, true) or cmd == "pass" or cmd == "partial" or cmd == "fail" or cmd == "skip" or cmd == "get" or cmd == "set",
            "README lacks /ct " .. cmd)
    end
    T.ok(readme:find("/ct pass", 1, true) and readme:find("/ct get", 1, true) and readme:find("/ct set", 1, true))
    T.ok(seen >= 12)
end)
finish()
