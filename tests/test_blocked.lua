-- Blocked and forbidden actions (#65): CheckThat's own record, the same with or without BugGrabber.
local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.stubClient({})
H.plain(ns)

local function bind(open, now)
    local list, t = {}, { now = now or 100, open = open ~= false }
    ns.Blocked.Bind(list, function() return t.now end, function() return t.open end)
    return list, t
end

test("a blocked action is one line with the time, a counter, the addon, the event and the function", function()
    local list = bind()
    T.eq(ns.Blocked.Record("ADDON_ACTION_BLOCKED", "KeepThat", "CastSpellByName()"), true)
    T.ok(list[1]:match("^100%.%d%d%d %[KeepThat%] ADDON_ACTION_BLOCKED CastSpellByName%(%)$"), list[1])
    T.ok(ns.Blocked.Record("ADDON_ACTION_FORBIDDEN", "X", "UseAction()"))
    T.ok(ns.Blocked.Record("MACRO_ACTION_BLOCKED", "TargetUnit()"))
    T.ok(list[3]:find("[macro] MACRO_ACTION_BLOCKED TargetUnit()", 1, true), "a macro event names no addon")
    T.eq(ns.Blocked.Count(), 3)
end)

test("nothing is recorded with no run open, for another event, or without a store", function()
    local list, t = bind(false)
    T.eq(ns.Blocked.Record("ADDON_ACTION_BLOCKED", "A", "f()"), false)
    t.open = true
    T.eq(ns.Blocked.Record("PLAYER_LOGIN", "A", "f()"), false)
    T.eq(#list, 0)
end)

test("a payload with brackets, control characters or nothing is made safe", function()
    local list = bind()
    ns.Blocked.Record("ADDON_ACTION_BLOCKED", "Evil]\n[KeepThat", nil)
    T.ok(list[1]:find("[EvilKeepThat] ADDON_ACTION_BLOCKED ?", 1, true), list[1])
end)

test("at most RATE lines a second and MAX lines kept", function()
    local list, t = bind()
    for i = 1, ns.Blocked.RATE + 5 do ns.Blocked.Record("ADDON_ACTION_BLOCKED", "A", "f" .. i) end
    T.eq(#list, ns.Blocked.RATE, "the rest of the second is dropped")
    for s = 1, 10 do t.now = 100 + s; for i = 1, ns.Blocked.RATE do ns.Blocked.Record("ADDON_ACTION_BLOCKED", "A", "f" .. i) end end
    T.eq(#list, ns.Blocked.MAX)
end)

test("BugGrabber's copy of a blocked action stays out of the error list, so the verdict does not depend on BugGrabber", function()
    local errs, t = {}, { now = 100 }
    local db = { BugGrabberDB = { errors = { { message = "old", counter = 1 } } } }
    ns.Errors.Bind(errs, function() return t.now end, function() return true end, db)
    H.stub(ns.Adapter, "ErrorHookState", function() return "blocked" end)
    T.eq(ns.Errors.Sample(), 0, "the first call takes the counters")
    db.BugGrabberDB.errors[2] = { message = "[ADDON_ACTION_BLOCKED] AddOn 'KeepThat' tried to call the protected function 'CastSpellByName()'.", counter = 1 }
    db.BugGrabberDB.errors[3] = { message = "Interface\\AddOns\\X\\a.lua:1: real error", counter = 1 }
    T.eq(ns.Errors.Sample(), 1, "only the Lua error is recorded")
    T.ok(errs[1]:find("real error", 1, true))
    T.ok(ns.Blocked.IsEventMessage("[ADDON_ACTION_FORBIDDEN] AddOn 'X' tried to call"))
    T.ok(not ns.Blocked.IsEventMessage("[string]:1: [ADDON_ACTION_BLOCKED] inside"), "only a message that starts with the event")
end)


finish()
