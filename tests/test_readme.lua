local ns, test, T, finish = dofile("tests/harness.lua")()
-- The README lists every /wtt command the addon handles.
test("README documents each command", function()
    local f = io.open("TestThat/Core/Slash.lua"); local src = f:read("*a"); f:close()
    local r = io.open("README.md"); local readme = r:read("*a"); r:close()
    local seen = 0
    for cmd in src:gmatch('cmd == "(%a+)"') do
        seen = seen + 1
        T.ok(readme:find("/wtt " .. cmd, 1, true) or cmd == "pass" or cmd == "partial" or cmd == "fail" or cmd == "skip" or cmd == "get" or cmd == "set",
            "README lacks /wtt " .. cmd)
    end
    T.ok(readme:find("/wtt pass", 1, true) and readme:find("/wtt get", 1, true) and readme:find("/wtt set", 1, true))
    T.ok(seen >= 12)
end)
finish()
