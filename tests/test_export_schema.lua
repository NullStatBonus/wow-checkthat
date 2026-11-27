-- Plays a run through the real App (verdicts, a stale macro press, Undo, a rerun, End) and writes each Run.Export to
-- build/export-runs.json. tools/test_ct.py validates every one against schema/run-results.schema.json, so a new key
-- the writer adds cannot drift from the schema.
local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local App = ns.App

local function plan()
    return { kind = "plan", ct = 1, addon = "KeepThat", title = "KT",
        sections = { { id = "s", title = "S", steps = {
            { id = "kt.1", title = "One", action = { kind = "manual", text = "do" }, expect = "ok", verify = { "player" } },
            { id = "kt.2", title = "Two", action = { kind = "manual", text = "do" }, expect = "ok", verify = { "player" } },
            { id = "kt.3", title = "Three", action = { kind = "manual", text = "do" }, expect = "ok", verify = { "player" } } } } } }
end

test("every export of a played run is written for the schema check", function()
    local env = { time = function() return 1000 end, GetBuildInfo = function() return "1.15.7", "63000", "x", 11507 end,
        UnitName = function() return "Tester" end, GetRealmName = function() return "Realm" end }
    App.Init({}, env)
    T.ok(App.ImportPlan(assert(ns.Codec.Encode(plan()))))
    App.Start("KeepThat")
    local out = {}
    local function snap() out[#out + 1] = ns.Run.Export((App.Current())) end
    snap()
    App.Begin(); App.Verdict("skip"); snap()
    App.Begin(); App.MacroRun("kt.1"); snap()                 -- a stale press on the step the card shows
    App.Verdict("fail", "broken"); snap()
    App.Undo(); snap()
    App.Begin(); App.Verdict("pass"); snap()
    App.Rerun("failed"); snap()
    local run = App.Current(); ns.Run.End(run, 2000); snap()
    T.eq(#out, 8)
    local last = out[8]
    -- A second run with formatRev 6 keys: ticks on listed actions, an async pass at start, an inapplicable step.
    env.UnitClass = function() return "Hunter", "HUNTER" end
    env.KeepThatDB = { global = { log = { "[kt] ready" } } }
    local p2 = plan()
    p2.logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } }
    p2.requirements = { caster = { text = "This step needs a Mage.", class = { "MAGE" }, unmet = "inapplicable" } }
    p2.sections[1].steps[1] = { id = "kt.1", title = "Ready", action = { kind = "manual", text = "Wait." }, expect = "ok", verify = { "assertions" },
        auto = true, async = true, assertions = { { kind = "log", source = "debug", contains = "ready" } } }
    p2.sections[1].steps[2].action.text = { "Open the bag.", "Close it." }
    p2.sections[1].steps[3].requires = { "caster" }
    T.ok(App.ImportPlan(assert(ns.Codec.Encode(p2))))
    App.Start("KeepThat"); snap()
    App.Begin(); App.Tick(1, true); snap()
    App.Verdict("pass"); App.Begin(); snap()
    local json = assert(ns.Json.Encode(out))
    local f = assert(io.open("build/export-runs.json", "wb")); f:write(json); f:close()
    T.ok(last.endedAt, "the last export is of an ended run")
    local stale = 0
    for _, rec in pairs(last.steps) do stale = stale + (rec.macroStale or 0) end
    T.eq(stale, 1, "the stale press is in the export")
    local two = out[#out]
    T.eq(two.steps["kt.1"].attempts[1].at, "start"); T.same(two.steps["kt.2"].attempts[1].ticks, { 1000, false })
    T.eq(two.steps["kt.3"].verdict, "inapplicable"); T.eq(two.steps["kt.3"].unmet, "This step needs a Mage.")
end)
finish()
