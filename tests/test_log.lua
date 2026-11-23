local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)

test("recording off adds nothing; on is bounded", function()
    local store, on = { entries = {} }, false
    ns.Log.Bind(store, function() return on end, function() return 42 end)
    ns.Log.Record("a", "x"); T.eq(#store.entries, 0)
    on = true
    for i = 1, 400 do ns.Log.Record("a", "m" .. i) end
    T.eq(#store.entries, 300); T.eq(store.entries[300].msg, "[a] m400"); T.eq(store.entries[1].t, 42)
end)
test("failures are kept even when recording is off; clear keeps nothing else", function()
    local store = { entries = {}, other = "keep" }
    ns.Log.Bind(store, function() return false end)
    ns.Log.failures = {}
    ns.Log.Failure("start", "boom")
    T.eq(#ns.Log.failures, 1); T.eq(#store.entries, 0)
    ns.Log.Clear(); T.eq(#ns.Log.failures, 0); T.eq(store.other, "keep")
end)
test("report names the stored runs, the run limit and the plan copies", function()
    ns.App.Init({ runs = { a = {}, b = {} }, planStore = { x = {} }, runLimit = 30 }, {})
    local r = ns.Log.Report()
    T.ok(r:find("Stored: 2 runs %(limit 30%), 1 plan copies"), r)
end)
test("report names version, settings area and log state", function()
    ns.Log.Bind({ entries = { { t = 1, msg = "[ct] hello" } } }, function() return true end)
    local r = ns.Log.Report()
    T.ok(r:find("CheckThat") and r:find("Failures:") and r:find("%[ct%] hello") and r:find("recording"), r)
end)
finish()
