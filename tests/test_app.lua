local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local App = ns.App
local function plan()
    return { kind = "plan", wtt = 1, addon = "KeepThat", title = "KT",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        macros = { { id = "dbg", text = "/kt debug on\n/reload" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "kt.1", title = "Hover", action = { kind = "secure-macro", macro = "dbg", commands = { "/kt log" } }, expect = "one line",
              verify = { "player", "assertions" }, reload = "after_action",
              assertions = { { kind = "log", source = "debug", contains = "[merchant] started", scope = "session" } } },
            { id = "kt.2", title = "Next", action = { kind = "manual", text = "do" }, expect = "ok", verify = { "player" } } } } } }
end
local function boot()
    local env = { KeepThatDB = { global = { log = { "boot" } } }, time = function() return 1000 end,
        GetBuildInfo = function() return "1.15.7", "63000", "x", 11507 end,
        UnitName = function() return "Tester" end, GetRealmName = function() return "Realm" end }
    local db = {}
    App.Init(db, env)
    return db, env
end
test("app import stores plan, rejects bad ones without state change", function()
    local db = boot()
    local s = assert(ns.Codec.Encode(plan()))
    T.ok(App.ImportPlan(s))
    T.ok(db.plans.KeepThat)
    local bad = plan(); bad.sections[1].steps[1].action.kind = "cast"
    local db2 = boot()
    local v, err = App.ImportPlan(assert(ns.Codec.Encode(bad)))
    T.ok(v == nil and err:find("not valid"), err)
    T.ok(next(db2.plans) == nil, "nothing stored")
    local r, e2 = App.ImportPlan(assert(ns.Codec.Encode({ kind = "results", wtt = 1 })))
    T.ok(r == nil and e2:find("results"))
end)
test("character key falls back when the realm name is empty", function()
    local db, env = boot()
    env.GetRealmName = function() return "" end
    T.eq(App.Character(), "Tester-?")
    env.GetNormalizedRealmName = function() return "Realm" end
    T.eq(App.Character(), "Tester-Realm")
end)
test("character key prefers the full name with realm", function()
    local db, env = boot()
    env.UnitFullName = function() return "Tester", "Realm" end
    T.eq(App.Character(), "Tester-Realm")
    env.UnitFullName = function() return "Tester", nil end
    env.GetNormalizedRealmName = function() return "" end
    env.GetRealmName = function() return "Realm" end
    T.eq(App.Character(), "Tester-Realm", "falls through an empty first answer")
end)
test("app detects client by interface number", function()
    local _, env = boot()
    T.eq(App.Client(), "classic-era")
    env.GetBuildInfo = function() return "1.60", "1", "x", 16001 end
    T.eq(App.Client(), "forever-camelot")
end)
test("app run, reload resume, export and decode", function()
    local db, env = boot()
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    local run = assert(App.Start("KeepThat"))
    T.eq(run.client, "classic-era")
    local _, step = App.Begin()
    T.eq(step.id, "kt.1")
    -- simulate /reload: saved db survives, session log gains the startup line
    env.KeepThatDB.global.log[#env.KeepThatDB.global.log + 1] = "[merchant] started"
    local run2, _, step2 = App.Current()
    T.eq(run2.runId, run.runId); T.eq(step2.id, "kt.1")
    local a = App.Verdict("pass")
    T.eq(a.verdict, "pass"); T.eq(a.evidence, "matched")
    local s = assert(App.Export())
    local back = assert(ns.Codec.Decode(s))
    T.eq(back.kind, "results"); T.eq(back.steps["kt.1"].verdict, "pass")
    T.ok(back.steps["kt.2"].attempts[1] == nil or back.steps["kt.2"].attempts[1].snapshots == nil, "no snapshots exported")
end)
test("importing a plan marks it pending; starting clears it", function()
    local db = boot()
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    T.eq(db.ui.pendingStart, "KeepThat")
    App.Start("KeepThat"); T.eq(db.ui.pendingStart, nil)
end)
test("recent plans: newest first, no duplicates, capped, reusable without pasting", function()
    local db = boot()
    local function planFor(i) local p = plan(); p.title = "P" .. i; p.sections[1].steps[1].id = "kt." .. i; return p end
    for i = 1, 10 do App.ImportPlan(assert(ns.Codec.Encode(planFor(i)))) end
    local r = App.Recent()
    T.eq(#r, 8); T.ok(r[1].text:find("P10"), r[1].text)
    -- importing P9 again moves it to the front without duplicating
    App.ImportPlan(assert(ns.Codec.Encode(planFor(9))))
    T.ok(App.Recent()[1].text:find("P9")); T.eq(#App.Recent(), 8)
    -- pick an older entry: it becomes the current plan again
    local id = App.Recent()[3].id
    local picked = assert(App.UseRecent(id))
    T.eq(App.db.plans.KeepThat.digest, id); T.eq(App.db.ui.lastImport, "KeepThat")
    T.eq(App.Recent()[1].id, id)
    local none, err = App.UseRecent("deadbeef"); T.ok(none == nil and err:find("no longer stored"))
end)
test("copyables and macro text re-check the allow list", function()
    local db = boot()
    local p = plan()
    local step = p.sections[1].steps[1]
    local c = App.Copyables(step, p)
    T.eq(c[1], "/kt log"); T.eq(c[2], "/kt debug on"); T.eq(c[3], "/reload")
    T.eq(App.MacroText(step, p), "/kt debug on\n/reload")
    p.macros[1].text = "/run x"
    T.ok(App.MacroText(step, p) == nil, "disallowed macro never offered")
end)
test("app debug log is bounded and off by default", function()
    local db = boot()
    App.Log("x"); T.eq(#db.log.entries, 0)
    db.log.enabled = true
    for i = 1, 400 do App.Log("m" .. i) end
    T.eq(#db.log.entries, 300)
end)
test("run resolves the plan it started with, not the latest import", function()
    boot()
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    App.Start("KeepThat")
    local changed = plan(); changed.title = "KT v2"; changed.sections[1].steps[1].id = "kt.other"
    App.ImportPlan(assert(ns.Codec.Encode(changed)))
    local _, _, step = App.Current()
    T.eq(step.id, "kt.1", "active run keeps its own plan")
end)
test("current run is per character", function()
    local db, env = boot()
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    App.Start("KeepThat")
    T.ok(App.Current())
    env.UnitName = function() return "Other" end
    T.ok(App.Current() == nil, "other character has no active run")
    env.UnitName = function() return "Tester" end
    T.ok(App.Current())
end)
test("undo follows commit order and drops the open retry", function()
    local db, env = boot()
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    App.Start("KeepThat")
    App.Begin(); App.Verdict("skip")           -- kt.1
    App.Begin(); App.Verdict("fail")           -- kt.2 fails
    App.Begin()                                -- retry opened by refresh
    local ok, id = App.Undo()
    T.eq(id, "kt.2"); T.ok(ok)
    local run = App.Current()
    T.eq(run.steps["kt.2"].verdict, "pending"); T.eq(#run.steps["kt.2"].attempts, 0)
    T.eq(run.steps["kt.1"].verdict, "skip", "earlier step untouched")
end)
test("reload mark on the open attempt", function()
    boot(); App.ImportPlan(assert(ns.Codec.Encode(plan()))); App.Start("KeepThat")
    App.Begin(); App.MarkReloaded()
    local run, _, step = App.Current()
    local rec = run.steps[step.id]
    T.ok(rec.attempts[#rec.attempts].reloaded)
end)
test("a manual step with allowed commands gets a Run macro; a disallowed one gets none", function()
    local db = boot()
    local p = plan()
    local step = p.sections[1].steps[2]
    step.action = { kind = "manual", text = "do", commands = { "/kt log", "/reload" } }
    T.eq(App.MacroText(step, p), "/kt log\n/reload")
    step.action.commands = { "/kt log", "/script x()" }
    T.ok(App.MacroText(step, p) == nil, "one disallowed line removes the Run button")
    step.action = { kind = "manual", text = "do" }
    T.ok(App.MacroText(step, p) == nil, "no commands, no macro")
end)
test("copyables are one command per line", function()
    local p = plan()
    local c = App.Copyables(p.sections[1].steps[1], p)
    T.eq(c[1], "/kt log"); T.eq(c[2], "/kt debug on"); T.eq(c[3], "/reload")
end)
test("status line", function()
    boot(); App.ImportPlan(assert(ns.Codec.Encode(plan()))); App.Start("KeepThat")
    T.ok(App.Status():find("2 left"), App.Status())
end)
finish()
