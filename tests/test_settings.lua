local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)

test("keys validate and write only on success", function()
    ns.defaults.profile.card.scale = 100
    local ok = ns.Settings.Set("card.scale", "150"); T.ok(ok)
    T.eq(ns.Settings.Get("card.scale"), 150)
    for _, bad in ipairs({ "500", "10", "1.5", "abc", "", "-5" }) do
        local good, msg = ns.Settings.Set("card.scale", bad)
        T.ok(not good and msg, "rejects " .. bad)
        T.eq(ns.Settings.Get("card.scale"), 150, "unchanged after " .. bad)
    end
    T.ok(ns.Settings.Set("card.locked", "on")); T.eq(ns.Settings.Value("card.locked"), "on")
    T.ok(not ns.Settings.Set("card.locked", "maybe"))
    local ok2, msg = ns.Settings.Set("nope.key", "1"); T.ok(not ok2 and msg:find("Unknown key"))
end)
test("onChange fires on success only", function()
    local n = 0
    ns.Settings.onChange = function() n = n + 1 end
    ns.Settings.Set("card.text-opacity", "80"); ns.Settings.Set("card.text-opacity", "999")
    T.eq(n, 1)
end)
test("status lists every key", function() T.eq(#ns.Settings.Status(), 5) end)
test("card.sound is on by default and takes on or off (#229)", function()
    T.eq(ns.Settings.Get("card.sound"), true)
    T.ok(ns.Settings.Set("card.sound", "off")); T.eq(ns.Settings.Get("card.sound"), false)
    T.ok(ns.Settings.Set("card.sound", "on")); T.eq(ns.Settings.Get("card.sound"), true)
    T.ok(not ns.Settings.Set("card.sound", "loud"))
end)
test("a change is logged, so a plan can check it", function()
    local said = {}
    H.stub(ns.App, "Log", function(m) said[#said + 1] = m end)
    ns.Settings.Set("card.sound", "off"); ns.Settings.Set("card.sound", "on"); ns.Settings.Set("card.sound", "loud")
    T.same(said, { "setting card.sound = false", "setting card.sound = true" })
end)
finish()
