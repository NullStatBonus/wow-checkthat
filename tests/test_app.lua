local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local App = ns.App
local function plan()
    return { kind = "plan", ct = 1, addon = "KeepThat", title = "KT",
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
    local r, e2 = App.ImportPlan(assert(ns.Codec.Encode({ kind = "results", ct = 1 })))
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

test("a macro with more lines than copy boxes is not offered as one button", function()
    boot()
    local p = plan()
    local step = p.sections[1].steps[2]
    step.action = { kind = "manual", text = "do", commands = { "/kt log", "/kt log", "/kt log", "/kt log" } }
    T.ok(App.MacroText(step, p) ~= nil, "four lines fit")
    step.action.commands[5] = "/kt log"
    T.ok(App.MacroText(step, p) == nil, "five lines hide commands the tester cannot see")
end)
test("a different plan with the same checksum does not replace a stored plan", function()
    local db = boot()
    local a = plan(); local sa = assert(ns.Codec.Encode(a))
    local digest = sa:match("^!CT1!(%x+)!")
    T.ok(App.ImportPlan(sa))
    local other = plan(); other.title = "Other"; other.sections[1].steps[1].id = "kt.x"
    db.planStore[digest] = other                          -- simulate a collision with a different stored plan
    T.ok(App.ImportPlan(sa))
    T.ok(db.plans.KeepThat.digest ~= digest, "new key allocated")
    T.eq(db.planStore[digest].title, "Other", "stored plan untouched")
end)
test("import errors are player sentences; damaged data never raises", function()
    boot()
    local bad = plan(); bad.macros[1].text = "/run x"
    local v, err = App.ImportPlan(assert(ns.Codec.Encode(bad)))
    T.ok(v == nil and err:find("does not allow"), err)
    T.ok(not err:find("macro not allowed"), "no raw validator text")
    local ok, r, e2 = pcall(App.ImportPlan, "!CT1!00000000!====")
    T.ok(ok and r == nil and e2, "damaged string")
    local md = plan(); md.title = "A `x`"
    local _, e3 = App.ImportPlan(assert(ns.Codec.Encode(md)))
    T.ok(e3:find("backticks"), e3)
end)

test("an automatic result is logged, labelled and exported", function()
    local db, env = boot()
    db.log.enabled = true
    local p = plan()
    local st = p.sections[1].steps[1]
    st.verify = { "assertions" }; st.auto = true; st.reload = nil; st.assertions[1].scope = nil; st.assertions[1].contains = "auto line"
    App.ImportPlan(assert(ns.Codec.Encode(p)))
    App.Start("KeepThat"); App.Begin()
    T.eq(App.AutoSettle(), nil, "nothing yet")
    env.KeepThatDB.global.log[#env.KeepThatDB.global.log + 1] = "auto line"
    local a, step = App.AutoSettle()
    T.eq(a.verdict, "pass"); T.eq(step.id, "kt.1")
    local found
    for _, e in ipairs(db.log.entries) do
        local m = type(e) == "table" and e.msg or e
        if tostring(m):find("step kt.1 pass auto evidence matched", 1, true) then found = true end
    end
    T.ok(found, "log line missing")
    local back = assert(ns.Codec.Decode(assert(App.Export())))
    T.eq(back.steps["kt.1"].attempts[1].by, "auto", "the results string says CheckThat recorded it")
end)

test("app end: keeps results, marks the export, blocks verdicts and undo", function()
    local db, env = boot()
    db.log.enabled = true
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    local run = assert(App.Start("KeepThat"))
    T.ok(App.CanEnd())
    App.Begin(); App.Verdict("skip")
    T.ok(App.End("some-other-run") == nil, "a stale confirmation ends nothing")
    T.eq(run.endedAt, nil)
    T.ok(App.End(run.runId)); T.eq(run.endedAt, 1000)
    local _, _, step = App.Current(); T.eq(step, nil, "no current step")
    local a, err = App.Verdict("pass"); T.ok(a == nil and err:find("has ended"), err)
    T.eq(App.Undo(), false)
    T.ok(App.Status():find("run ended"), App.Status())
    local ended, why = App.End(); T.ok(ended == nil and why:find("already ended"), why)
    local c, why2 = App.CanEnd(); T.ok(c == nil and why2:find("already ended"))
    local back = assert(ns.Codec.Decode(assert(App.Export())))
    T.eq(back.endedAt, 1000); T.eq(back.steps["kt.1"].verdict, "skip"); T.eq(back.steps["kt.2"].verdict, "pending")
    local logged = false
    for _, e in ipairs(db.log.entries) do if e.msg:find("run ended " .. run.runId, 1, true) then logged = true end end
    T.ok(logged, "the debug log records the end")
end)
test("app clear plan: ends the run, forgets the plan, keeps the results exportable", function()
    local db = boot()
    db.log.enabled = true
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    local run = assert(App.Start("KeepThat"))
    App.Begin(); App.Verdict("skip")
    local digest = run.planDigest
    T.ok(App.db.plans.KeepThat and #App.Recent() == 1, "the plan is loaded and recent")
    T.ok(App.ClearPlan("some-other-run") == nil, "a stale confirmation clears nothing")
    T.eq(run.endedAt, nil); T.ok(App.db.plans.KeepThat, "the plan stays")
    T.ok(App.ClearPlan(run.runId)); T.eq(run.endedAt, 1000, "the run ended")
    T.eq(App.db.plans.KeepThat, nil, "no loaded plan")
    T.eq(App.db.ui.lastImport, nil); T.eq(App.db.ui.pendingStart, nil)
    T.eq(#App.Recent(), 0, "not in the recent list")
    T.ok(App.db.planStore[digest], "the stored plan stays for the ended run")
    local back = assert(ns.Codec.Decode(assert(App.Export())))
    T.eq(back.steps["kt.1"].verdict, "skip"); T.eq(back.endedAt, 1000)
    local logged, ended = false, false
    for _, e in ipairs(db.log.entries) do
        if e.msg:find("plan cleared KeepThat", 1, true) then logged = true end
        if e.msg:find("run ended " .. run.runId, 1, true) then ended = true end
    end
    T.ok(logged and ended, "the debug log records both the end and the clear")
    local again, why = App.ClearPlan(); T.ok(again == nil and why:find("already ended"), tostring(why))
end)
test("app end with no run", function()
    boot()
    local run, err = App.CanEnd(); T.ok(run == nil and err:find("no run"))
    local r2, e2 = App.End(); T.ok(r2 == nil and e2:find("no run"))
end)
test("context menu: MenuUtil, then UIDropDownMenu, then false", function()
    local Ad = ns.Adapter
    local clicked
    local items = { { "End run...", function() clicked = true end } }
    local saved = { MenuUtil = _G.MenuUtil, UDM_I = _G.UIDropDownMenu_Initialize }
    _G.MenuUtil, _G.UIDropDownMenu_Initialize = nil, nil
    T.eq(Ad.ContextMenu({}, items), false, "no menu API")
    local made
    _G.MenuUtil = { CreateContextMenu = function(owner, gen)
        gen(owner, { CreateButton = function(_, text, fn) made = { text, fn } end }) end }
    T.eq(Ad.ContextMenu({}, items), true); T.eq(made[1], "End run..."); made[2](); T.ok(clicked)
    _G.MenuUtil = { CreateContextMenu = function() error("boom") end }
    T.eq(Ad.ContextMenu({}, items), false, "a failing menu falls back")
    _G.MenuUtil, _G.UIDropDownMenu_Initialize = saved.MenuUtil, saved.UDM_I
end)
-- Run history, run limit and plan pruning
local function withRuns(n, char)
    local db, env = boot()
    env.UnitName = function() return char or "Tester" end
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    local ids = {}
    for i = 1, n do
        env.time = function() return 1000 + i end
        local run = assert(App.Start("KeepThat"))
        ids[i] = run.runId
        App.End()
    end
    return db, env, ids
end
test("a stored plan copy goes when no run, loaded plan or recent entry names it", function()
    local db = boot()
    local p1 = plan()
    local p2 = plan(); p2.title = "KT two"
    App.ImportPlan(assert(ns.Codec.Encode(p1)))
    local d1 = db.plans.KeepThat.digest
    App.ImportPlan(assert(ns.Codec.Encode(p2)))
    local d2 = db.plans.KeepThat.digest
    T.ok(db.planStore[d1] and db.planStore[d2], "a recent entry still names the first")
    db.ui.recent = {}
    App.PrunePlans()
    T.eq(db.planStore[d1], nil, "orphan revision removed"); T.ok(db.planStore[d2], "loaded plan kept")
    local run = assert(App.Start("KeepThat"))
    App.ClearPlan()
    T.ok(db.planStore[d2], "the ended run still names it")
    T.ok(App.Current() ~= nil and App.Current().runId == run.runId)
    App.DeleteRun(run.runId)
    T.eq(db.planStore[d2], nil, "no run, loaded plan or recent entry names it")
end)
test("runs beyond the limit are pruned oldest first and the current run stays", function()
    local db, env, ids = withRuns(7)
    db.runLimit = 10
    T.eq(#App.Runs(), 7)
    db.runLimit = 5
    App.PruneRuns()
    T.eq(#App.Runs(), 5)
    T.eq(db.runs[ids[1]], nil); T.eq(db.runs[ids[2]], nil); T.ok(db.runs[ids[3]] and db.runs[ids[7]])
    env.time = function() return 2000 end
    local live = assert(App.Start("KeepThat"))
    T.eq(#App.Runs(), 5, "never above the limit")
    T.eq(db.runs[ids[3]], nil, "the oldest went")
    T.ok(db.runs[live.runId] and db.currentByChar[App.Character()] == live.runId, "the new current run stays")
end)
test("the limit never removes any character's current run", function()
    local db, env, ids = withRuns(7, "Anna")
    db.currentByChar["Zed-Realm"] = ids[1] -- the oldest run is another character's current run
    db.runLimit = 5
    App.PruneRuns()
    T.ok(db.runs[ids[1]], "current run of another character kept")
    T.eq(#App.Runs(), 5, "the others gave way")
    db.runLimit = 1; T.eq(App.RunLimit(), 5, "an out of range value is clamped")
    db.runLimit = 500; T.eq(App.RunLimit(), 100)
    db.runLimit = nil; T.eq(App.RunLimit(), 20)
end)
test("Runs lists newest first with counts", function()
    local db, env, ids = withRuns(3)
    local rows = App.Runs()
    T.eq(rows[1].id, ids[3]); T.eq(rows[3].id, ids[1])
    T.ok(rows[1].text:find("KT") and rows[1].text:find("Tester") and rows[1].text:find("open"), rows[1].text)
    T.ok(rows[1].ended)
end)
test("OpenRun shows an ended run, refuses another character's unfinished run", function()
    local db, env, ids = withRuns(2)
    local before = db.currentByChar[App.Character()]
    T.ok(not App.OpenAsks(ids[1]), "no active run, no question")
    local opened = App.OpenRun(ids[1])
    T.eq(opened.runId, ids[1]); T.eq(db.currentByChar[App.Character()], before, "viewing changes no current run")
    local run = App.Current()
    T.eq(run.runId, ids[1]); T.ok(run.endedAt, "read-only")
    T.eq(App.Status():find(ids[1], 1, true) ~= nil, true, "status names the run on the card")
    local seen, record = {}, ns.Log.Record
    ns.Log.Record = function(_, msg) seen[#seen + 1] = msg end
    local s = assert(App.Export()); T.ok(s:find("^!CT1!"))
    ns.Log.Record = record
    T.ok((function() for _, m in ipairs(seen) do if m:find("run exported ", 1, true) then return true end end end)(), "an export is logged")
    local why = select(2, App.CanEnd()); T.ok(why:find("already ended"), "End run acts on the ended run on the card")
    local live = assert(App.Start("KeepThat"))
    T.eq(App.Current().runId, live.runId, "a new run clears the view")
    T.ok(not App.OpenReplacesRun(ids[1]), "viewing an ended run takes nothing from the live run")
    T.ok(App.OpenAsks(ids[1]), "but it still asks while a run is active")
    T.ok(not App.OpenAsks(live.runId), "the current run asks nothing")
    T.ok(not App.OpenAsks("nope"), "no run, no question")
    App.OpenRun(ids[2]); T.eq(App.Current().runId, ids[2]); T.eq(db.currentByChar[App.Character()], live.runId)
    App.OpenRun(live.runId); T.eq(App.Current().runId, live.runId, "opening the current run returns to it")
    env.UnitName = function() return "Other" end
    local r, err = App.OpenRun(live.runId)
    T.ok(r == nil and err:find("another character"), err)
    T.ok(App.OpenRun(ids[2]), "an ended run opens for anyone")
    local r2, err2 = App.OpenRun("nope")
    T.ok(r2 == nil and err2:find("no run"), err2)
end)
test("opening another unfinished run takes the card and starts its open attempt again", function()
    local db, env = boot()
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    env.time = function() return 1000 end
    local a = assert(App.Start("KeepThat"))
    ns.Run.Begin(a, App.Ctx(a), "kt.1")
    T.eq(#a.steps["kt.1"].attempts, 1)
    env.time = function() return 2000 end
    local b = assert(App.Start("KeepThat"))
    T.ok(App.OpenReplacesRun(a.runId), "asks before one live run replaces another")
    T.ok(not App.OpenReplacesRun(b.runId))
    env.time = function() return 3000 end
    App.OpenRun(a.runId)
    T.eq(App.Current().runId, a.runId); T.eq(db.currentByChar[App.Character()], a.runId)
    T.eq(#a.steps["kt.1"].attempts, 0, "the open attempt from before is dropped")
    local fresh = ns.Run.Begin(a, App.Ctx(a), "kt.1")
    T.eq(fresh.started, 3000, "the new attempt counts from now")
end)
test("a run deleted while viewed clears the view", function()
    local db, env, ids = withRuns(2)
    App.OpenRun(ids[1]); T.eq(App.Current().runId, ids[1])
    T.ok(App.DeleteRun(ids[1]))
    T.eq(db.ui.view[App.Character()], nil)
    T.eq(App.Current().runId, ids[2], "the card falls back to the current run")
end)
test("DeleteRun removes the run and clears the card when it was current", function()
    local db, env, ids = withRuns(2)
    local cur = db.currentByChar[App.Character()]
    T.ok(App.DeleteRun(cur))
    T.eq(db.runs[cur], nil); T.eq(App.Current(), nil, "card falls back to the start screen")
    T.eq(db.currentByChar[App.Character()], nil, "no dangling pointer to the deleted run")
    local ok, err = App.DeleteRun(cur)
    T.ok(ok == nil and err:find("no run"), err)
end)
finish()
