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
test("a plan that needs a newer CheckThat is refused with that sentence, and nothing is stored", function()
    local db = boot()
    local p = plan(); p.needs = ns.Plan.REV + 1; p.brandNewKey = { 1 }
    local v, err = App.ImportPlan(assert(ns.Codec.Encode(p)))
    T.eq(v, nil)
    T.ok(err:find(("This plan needs a newer CheckThat. It uses plan revision %d, and this version reads up to %d."):format(ns.Plan.REV + 1, ns.Plan.REV), 1, true), err)
    T.ok(next(db.plans) == nil, "nothing stored")
end)

test("a started run records the tested addon's version from the client, and none when the client cannot say", function()
    H.stub(_G, "GetAddOnMetadata", _G.GetAddOnMetadata)
    local asked
    H.stub(_G, "C_AddOns", { GetAddOnMetadata = function(name, field) asked = { name, field }; if name == "KeepThat" then return "2.5.1" end end })
    do
        boot(); App.ImportPlan(assert(ns.Codec.Encode(plan())))
        T.eq(App.Start("KeepThat").targetVersion, "2.5.1"); T.eq(asked[1], "KeepThat"); T.eq(asked[2], "Version", "the plan's addon, not CheckThat")
        T.eq(ns.Adapter.AddonVersion("Missing"), nil, "an addon the client does not know")
        _G.C_AddOns.GetAddOnMetadata = function() error("boom") end
        T.eq(ns.Adapter.AddonVersion("KeepThat"), nil, "a failing call is caught")
        _G.C_AddOns.GetAddOnMetadata = function() return "" end
        T.eq(ns.Adapter.AddonVersion("KeepThat"), nil, "an empty version is unknown")
        H.stub(_G, "C_AddOns", nil); H.stub(_G, "GetAddOnMetadata", nil)
        T.eq(ns.Adapter.AddonVersion("KeepThat"), nil, "a client with no metadata call")
        boot(); App.ImportPlan(assert(ns.Codec.Encode(plan())))
        T.eq(App.Start("KeepThat").targetVersion, nil, "the key is absent, never 'unknown'")
    end
end)
test("a step that is already open keeps one error stack, a new attempt wants another", function()
    local db = boot()
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    App.Start("KeepThat")
    local n, real = 0, ns.Errors.StepStarted
    ns.Errors.StepStarted = function() n = n + 1 end
    App.Begin(); T.eq(n, 1, "a new attempt")
    App.Begin(); T.eq(n, 1, "the same open attempt: no second stack")
    ns.Errors.StepStarted = real
end)
test("a run of a newer major format is kept aside untouched, and comes back when this version can read it", function()
    local db, env = boot()
    local future = { kind = "results", ct = 2, runId = "Future-1", planDigest = "futuredigest", steps = "not even a table", started = 5, note = { deep = { 1, 2 } } }
    local copy = { kind = "results", ct = 2, runId = "Future-1", planDigest = "futuredigest", steps = "not even a table", started = 5 }
    db.runs["Future-1"] = future
    db.planStore.futuredigest = { addon = "KeepThat" }
    db.currentByChar["Tester-Realm"] = "Future-1"
    App.Init(db, env)
    T.eq(db.runs["Future-1"], nil, "no other code sees it"); T.ok(db.future["Future-1"] == future, "the very same table, untouched")
    for k, v in pairs(copy) do T.eq(future[k], v, k) end
    T.eq(App.FutureCount(), 1); T.eq(#App.Runs(), 0)
    T.eq(App.Current(), nil, "it is not the current run")
    H.stub(App.RUN_LIMIT, "min", 1); db.runLimit = 1
    for i = 1, 4 do db.runs["Old-" .. i] = { kind = "results", ct = 1, runId = "Old-" .. i, started = i, steps = {}, order = {}, character = "X" } end
    App.PruneRuns()
    T.ok(db.future["Future-1"] == future, "pruning does not touch it, and it takes no place in the limit")
    T.ok(db.planStore.futuredigest, "its plan stays")
    db.runs["Odd-1"] = { ct = 3 }  -- a run with no plan digest: the plans stored now stay
    db.planStore.other = { addon = "x" }
    App.SplitFuture(db)
    App.PrunePlans()
    T.ok(db.planStore.other, "plans stored when it was set aside stay: it may need any of them")
    db.planStore.later = { addon = "y" }
    App.PrunePlans()
    T.eq(db.planStore.later, nil, "a plan stored later is pruned as usual")
    db.future["Odd-1"] = nil
    H.stub(ns.Run, "MAJOR", 2)
    App.SplitFuture(db)
    T.ok(db.runs["Future-1"] == future, "it returns when this version reads its format"); T.eq(db.future, nil, "nothing is left aside")
end)
test("a ct that is not a whole number up to the known major is a run this version cannot read", function()
    local O = ns.Run.Opaque
    T.eq(O({}), false, "no ct: a run from before it was kept"); T.eq(O({ ct = 1 }), false)
    for _, c in ipairs({ 2, 2.0, 1.5, 0, -1, "1", "2", true, {} }) do T.eq(O({ ct = c }), true, tostring(c)) end
end)
test("a run set aside keeps its id: a new run never takes it, and a restore never overwrites a readable run", function()
    local db, env = boot()
    db.runs["KeepThat-1000-X"] = { ct = 2, runId = "KeepThat-1000-X", planDigest = "d", steps = "new" }
    App.Init(db, env)
    local future = db.future["KeepThat-1000-X"]
    db.runs["KeepThat-1000-X"] = { ct = 1, runId = "KeepThat-1000-X", steps = {}, order = {} }   -- a readable namesake appears
    local mine = db.runs["KeepThat-1000-X"]
    H.stub(ns.Run, "MAJOR", 2)
    App.SplitFuture(db)
    T.ok(db.runs["KeepThat-1000-X"] == mine, "the readable run is not overwritten")
    T.ok(db.future["KeepThat-1000-X"] == future, "both entries stay")
end)
test("a new run never takes the id of a run set aside", function()
    local db, env = boot()
    App.Init(db, env)
    local id = ("KeepThat-%d-%s"):format(1000, ns.Run.Tag(App.Character()))
    db.runs[id] = { ct = 2, runId = id, planDigest = "d", steps = "new" }
    App.SplitFuture(db)
    local aside = db.future[id]
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    local run = App.Start("KeepThat")
    T.eq(run.runId, id .. "x", "the id is taken"); T.ok(db.future[id] == aside, "the run set aside is unchanged"); T.ok(db.runs[run.runId] == run)
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
    db.log.enabled = true
    App.ImportPlan(assert(ns.Codec.Encode(plan())))
    App.Start("KeepThat")
    App.Begin(); App.Verdict("skip")           -- kt.1
    App.Begin(); App.Verdict("fail")           -- kt.2 fails
    App.Begin()                                -- retry opened by refresh
    local ok, id = App.Undo()
    T.eq(id, "kt.2"); T.ok(ok)
    local logged = 0
    for _, e in ipairs(ns.Log.Entries()) do if e.msg == "[ct] undo kt.2: reopened" then logged = logged + 1 end end
    T.eq(logged, 1, "undo logs the step it reopened")
    local run = App.Current()
    T.eq(run.steps["kt.2"].verdict, "pending"); T.eq(#run.steps["kt.2"].attempts, 0)
    T.eq(run.steps["kt.1"].verdict, "skip", "earlier step untouched")
end)
test("a slash verdict on a step that has a result needs Redo or Undo first", function()
    local db0 = boot(); db0.log.enabled = true; App.ImportPlan(assert(ns.Codec.Encode(plan()))); App.Start("KeepThat")
    App.Begin(); T.ok(App.Verdict("skip"))     -- kt.1
    App.Goto(-1)
    local a, err = App.Verdict("fail")
    T.ok(a == nil and err:find("has a result"), err)
    local logged = 0
    for _, e in ipairs(ns.Log.Entries()) do if e.msg == "[ct] verdict refused kt.1: step has a result" then logged = logged + 1 end end
    T.eq(logged, 1, "the refusal is logged")
    local run = App.Current()
    T.eq(run.steps["kt.1"].verdict, "skip"); T.eq(#run.steps["kt.1"].attempts, 1)
    App.Begin(); T.ok(App.Verdict("pass"), "after Redo a verdict is taken")
end)
test("PlanReads lists each log global and each global-value name once, sorted, and leaves frame probes out", function()
    local p = { logs = { kt = { global = "KeepThatDB", path = "global.log" }, again = { global = "KeepThatDB", path = "global.other" },
            ddt = { global = "DontDoThatDB", path = "log" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "a", assertions = { { kind = "state", probe = "global-value", name = "ZetaVar", op = "exists" },
                { kind = "state", probe = "frame-shown", name = "SomeFrame", op = "eq", value = true },
                { kind = "state", probe = "addon-loaded", name = "KeepThat" },
                { kind = "state", probe = "global-value", name = "KeepThatDB", path = "x", op = "exists" } } },
            { id = "b" } } } } }
    T.same(App.PlanReads(p), { "DontDoThatDB", "KeepThatDB", "ZetaVar" })
    T.same(App.PlanReads({ sections = {} }), {})
    T.eq(App.ReadsNote({ sections = {} }), nil, "a plan that reads nothing has no note")
    T.eq(App.ReadsNote(p), "This plan reads these variables: DontDoThatDB, KeepThatDB, ZetaVar. A results string can include what they hold.")
    for i = 1, 8 do p.logs["n" .. i] = { global = "Aaa" .. i, path = "x" } end
    local note = App.ReadsNote(p)
    T.ok(note:find("Aaa1, Aaa2, Aaa3, Aaa4, Aaa5, Aaa6, and 5 more.", 1, true), "six names, then a count: " .. note)
    T.ok(App.ReadsNote({ logs = { bar = { global = "A|cffff0000x", path = "x" } }, sections = {} }):find("A||cffff0000x", 1, true),
        "a name is escaped: the card shows it as text")
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
test("a macro body over the game's 255 characters is not offered", function()
    boot()
    local p = plan()
    local step = p.sections[1].steps[2]
    local long = "/kt log " .. ("x"):rep(255 - 8)
    step.action = { kind = "manual", text = "do", commands = { long } }
    T.eq(#long, 255)
    T.ok(App.MacroText(step, p) ~= nil, "255 characters fit")
    step.action.commands[1] = long .. "x"
    T.ok(App.MacroText(step, p) == nil, "256 characters do not")
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
test("CategorySteps lists a category's steps in plan order with words, and ShowStep only shows a step in the run", function()
    boot()
    T.eq(#App.CategorySteps("s"), 0, "no run, no steps")
    T.eq(App.ShowStep("kt.1"), nil)
    App.ImportPlan(assert(ns.Codec.Encode(plan()))); App.Start("KeepThat")
    local run = App.Current()
    T.ok(run, "a run is on the card")
    local cat = run.categories[1].id
    local steps = App.CategorySteps(cat)
    T.eq(#steps, 2); T.eq(steps[1].id, "kt.1"); T.eq(steps[1].title, "Hover"); T.eq(steps[1].word, "open"); T.eq(steps[2].id, "kt.2")
    for _, s in ipairs(steps) do T.eq(run.cat[s.id], cat); T.eq(s.offered, true) end
    T.eq(#App.CategorySteps("nothing"), 0)
    local ok, err = App.ShowStep("no-such-step")
    T.eq(ok, nil); T.eq(err, "That step is not in this run.")
    run.steps["kt.2"].verdict = "inapplicable"   -- what a step for another client reads
    local s2 = App.CategorySteps(cat)[2]
    T.eq(s2.word, "not for this client"); T.eq(s2.offered, false)
    local ok2, err2 = App.ShowStep("kt.2"); T.eq(ok2, nil); T.eq(err2, "That step is not in this run.")
    run.steps["kt.2"].verdict = "pending"
    T.eq(App.ShowStep(steps[#steps].id), true); T.eq(ns.Run.CurrentId(run), steps[#steps].id)
    local rev = run.revision
    run.endedAt = 1
    T.eq(App.ShowStep(steps[1].id), true, "an ended run still shows it"); T.eq(run.revision, rev, "and keeps its revision")
    run.endedAt = nil
end)

test("context menu: MenuUtil, then UIDropDownMenu, then false", function()
    local Ad = ns.Adapter
    local clicked
    local items = { { "End run...", function() clicked = true end } }
    for _, k in ipairs({ "MenuUtil", "UIDropDownMenu_Initialize", "ToggleDropDownMenu", "UIDropDownMenu_CreateInfo", "UIDropDownMenu_AddButton", "CreateFrame", "UIParent", "CheckThatMenu" }) do H.stub(_G, k, _G[k]) end
    _G.MenuUtil, _G.UIDropDownMenu_Initialize = nil, nil
    T.eq(Ad.ContextMenu({}, items), false, "no menu API")
    local made
    _G.MenuUtil = { CreateContextMenu = function(owner, gen)
        gen(owner, { CreateButton = function(_, text, fn) made = { text, fn } end }) end }
    T.eq(Ad.ContextMenu({}, items), true); T.eq(made[1], "End run..."); made[2](); T.ok(clicked)
    _G.MenuUtil = { CreateContextMenu = function() error("boom") end }
    T.eq(Ad.ContextMenu({}, items), false, "a failing menu falls back")
    local added = {}
    _G.UIDropDownMenu_Initialize = function(_, init) init() end
    _G.ToggleDropDownMenu = function() end
    _G.UIDropDownMenu_CreateInfo = function() return {} end
    _G.UIDropDownMenu_AddButton = function(info) added[#added + 1] = info end
    _G.CreateFrame, _G.UIParent = function() return {} end, {}
    T.eq(Ad.ContextMenu({}, items), true, "a failing MenuUtil falls through to the dropdown")
    T.eq(#added, #items)
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
    T.ok(rows[1].text:find("KT") and rows[1].text:find("Tester"), rows[1].text)
    T.ok(#rows[1].text < 50, "short enough for the dropdown: " .. rows[1].text)
    T.ok(#App.RunText(ids[1]) > #rows[1].text and App.RunText(ids[1]):find("open"), "the full text stays for questions")
    T.ok(rows[1].ended)
    T.ok(rows[1].text:find(", ended", 1, true), rows[1].text)
    local run = App.db.runs[ids[1]]; run.endedAt = nil
    T.ok(not App.Runs()[3].text:find("ended", 1, true), "an open run has no marker")
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
-- Categories
local function catPlan()
    local p = plan()
    p.sections = { { id = "bank", title = "Bank", steps = { p.sections[1].steps[1], p.sections[1].steps[2] } },
        { id = "mail", title = "Mail", steps = { { id = "kt.3", title = "Send", action = { kind = "manual", text = "do" }, expect = "ok", verify = { "player" } } } } }
    return p
end
local function started(picks)
    local db, env = boot()
    App.ImportPlan(assert(ns.Codec.Encode(catPlan())))
    local run, err = App.Start("KeepThat", picks)
    return db, env, run, err
end
test("category choices list each category with its step count", function()
    local db = boot()
    local ch = App.CategoryChoices(catPlan())
    T.eq(#ch, 2); T.eq(ch[1].id, "bank"); T.eq(ch[1].steps, 2); T.eq(ch[2].steps, 1)
end)
test("start with picks runs only those categories", function()
    local db, env, run = started({ "mail" })
    T.eq(run.steps["kt.1"].verdict, "deselected"); T.eq(#run.order, 1)
    T.ok(App.Status():find("2 not picked", 1, true), App.Status())
end)
test("start with nothing picked or an unknown pick does not start a run", function()
    local db, env, run, err = started({})
    T.eq(run, nil); T.ok(err:find("Pick at least one category"), err); T.eq(next(db.runs), nil)
    db, env, run, err = started({ "nope" })
    T.eq(run, nil); T.ok(err:find("no category called nope"), err); T.eq(next(db.runs), nil)
end)
test("start without picks runs every category", function()
    local db, env, run = started()
    T.eq(#run.order, 3); T.eq(run.selected.bank, true); T.eq(run.selected.mail, true)
end)
test("trigger and rerun go through the app and log", function()
    local db, env, run = started({ "bank" })
    local kind, id = App.Trigger("mail")
    T.eq(kind, "category"); T.eq(id, "kt.3"); T.eq(App.Current().runId, run.runId)
    local _, ctx, step = App.Current(); T.eq(step.id, "kt.3")
    local n, title = App.Rerun("bank"); T.eq(n, 0); T.eq(title, "Bank")
    local k, err = App.Trigger("zzz"); T.eq(k, nil); T.ok(err:find("no category or step called zzz"), err)
    local _, err2 = App.Rerun("zzz"); T.ok(err2:find("no category called zzz"), err2)
end)
test("trigger and rerun say so with no run, an ended run, or a category not picked", function()
    local db = boot()
    local _, err = App.Trigger("bank"); T.eq(err, "There is no run.")
    _, err = App.Rerun("bank"); T.eq(err, "There is no run.")
    local db2, env, run = started({ "bank" })
    _, err = App.Rerun("mail"); T.ok(err:find("not part of this run. Use /ct run mail to add it", 1, true), err)
    App.End(run.runId)
    _, err = App.Trigger("mail"); T.eq(err, "This run has ended.")
end)
test("a category with every step done says how to run it again", function()
    local db, env, run = started({ "mail" })
    App.Begin(); T.ok(App.Verdict("pass"))
    local k, err = App.Trigger("mail"); T.eq(k, nil); T.ok(err:find("Use /ct rerun mail to run them again", 1, true), err)
end)
test("categories rows and lines use words as well as colors", function()
    local db, env, run = started()
    App.Begin(); App.Verdict("fail", "bad")
    local rows, overall, total = App.Categories()
    T.eq(overall, "red"); T.eq(rows[1].state, "red"); T.eq(rows[2].state, "blue"); T.eq(total.total, 3)
    T.eq(App.CategoryLine(rows[1]), "Bank (bank): failed, 0 passed, 1 failed, 1 open")
    T.eq(App.CategoryLine(rows[2]), "Mail (mail): untested, 0 passed, 0 failed, 1 open")
    T.eq(App.StateWord("yellow"), "partial or unverified"); T.eq(App.StateWord("green"), "passed"); T.eq(App.StateWord("off"), "not picked")
    T.eq(App.StateWord("grey", { resolved = 2, open = 0 }), "all skipped", "grey says why")
    T.eq(App.StateWord("blue", { resolved = 0, open = 2 }), "untested"); T.eq(App.StateWord("blue", { resolved = 1, open = 1 }), "in progress")
    T.eq(App.StateWord("grey", { resolved = 0, open = 0 }), "no steps")
end)
test("a name that is both a category and a step changes nothing", function()
    local db, env, run = started()
    run.steps.bank = { attempts = {}, verdict = "pending" } -- a step id equal to a category id
    run.order[#run.order + 1] = "bank"
    local before = run.current
    local k, err = App.Trigger("bank")
    T.eq(k, nil); T.ok(err:find("both a category and a step", 1, true), err); T.eq(run.current, before)
end)
test("select adds a category and leaves the viewed step", function()
    local db, env, run = started({ "bank" })
    local _, _, step = App.Current()
    T.eq(App.Select("mail"), true); T.eq(select(3, App.Current()).id, step.id, "the card stays where it was")
    T.eq(run.steps["kt.3"].verdict, "pending")
    T.eq(App.Select("mail"), false, "already picked")
    local ok, err = App.Select("zzz"); T.eq(ok, nil); T.ok(err:find("no category called zzz"), err)
end)
test("a verdict that opens its own attempt asks for an error stack once, as the card does", function()
    local db, env, run = started()
    local n = 0
    H.stub(ns.Errors, "StepStarted", function() n = n + 1 end)
    App.Verdict("pass")                      -- a slash verdict: no App.Begin before it
    T.eq(n, 1, "the attempt it opened asked for a stack")
    App.Begin(); T.eq(n, 2); App.Begin(); T.eq(n, 2, "an open attempt asks once")
    App.Verdict("pass"); T.eq(n, 2, "closing the open attempt asks for nothing")
end)
test("deselect removes a clean category and says why it cannot", function()
    local db, env, run = started()
    local ok, err = App.Deselect("zzz"); T.eq(ok, nil); T.ok(err:find("no category called zzz"), err)
    App.Begin(); App.Verdict("pass")
    ok, err = App.Deselect("bank"); T.eq(ok, nil); T.ok(err:find("has results", 1, true), err)
    T.eq(App.Deselect("mail"), true); T.eq(run.steps["kt.3"].verdict, "deselected")
    ok, err = App.Deselect("mail"); T.ok(err:find("not part of this run", 1, true), err)
    ok, err = App.Deselect("bank"); T.ok(err:find("at least one category", 1, true), err)
end)
test("a slash verdict arms the stack before the errors are read", function()
    local db, env, run = started()
    local order = {}
    H.stub(ns.Errors, "StepStarted", function() order[#order + 1] = "armed" end)
    H.stub(ns.Errors, "Check", function() order[#order + 1] = "check" end)
    App.Verdict("pass")
    T.eq(order[1], "armed"); T.eq(order[2], "check")
end)
test("deselect refuses the last category", function()
    local db, env, run = started({ "bank" })
    local ok, err = App.Deselect("bank"); T.eq(ok, nil); T.ok(err:find("at least one category", 1, true), err)
end)
test("rerun count says how many steps a rerun would reopen", function()
    local db, env, run = started()
    T.eq((App.RerunCount("bank")), 0)
    App.Begin(); App.Verdict("pass")
    local n, title = App.RerunCount("bank"); T.eq(n, 1); T.eq(title, "Bank")
    local m, err = App.RerunCount("zzz"); T.eq(m, nil); T.ok(err:find("no category called zzz"), err)
end)
test("rerun failed counts and reopens the failed and unverified steps", function()
    local db, env, run = started()
    local n, title = App.RerunCount("failed"); T.eq(n, 0); T.eq(title, "failed and unverified steps")
    T.eq(App.NothingToReopen("failed", title), "No step has failed or is unverified.")
    T.eq(App.NothingToReopen("bank", "Bank"), "Nothing to reopen in Bank: no step has a result.")
    App.Begin(); App.Verdict("fail", "x")
    n = App.RerunCount("failed"); T.eq(n, 1)
    local m, t2 = App.Rerun("failed"); T.eq(m, 1); T.eq(t2, "failed and unverified steps")
    T.eq((App.RerunCount("failed")), 0)
end)
test("a stored run without categories is normalized when its context is built", function()
    local db, env, run = started()
    run.categories, run.cat, run.selected = nil, nil, nil
    T.ok(App.Ctx(run))
    T.eq(#run.categories, 2); T.eq(run.cat["kt.3"], "mail"); T.eq(run.selected.bank, true)
    T.ok(App.Categories())
end)
test("the debug report lists each category and the error handler", function()
    local db, env, run = started({ "bank" })
    local rep = ns.Log.Report()
    T.ok(rep:find("Categories: overall blue", 1, true), rep)
    T.ok(rep:find("  mail: off (not picked), 0 of 0 done", 1, true), rep)
end)

test("errors and facts are recorded for the open run while the card shows an ended run", function()
    local db, env, run = started()
    local ended = ns.Run.New({ plan = catPlan(), client = "classic-era", build = "1", character = App.Character(), now = 5, env = env, planDigest = run.planDigest })
    ended.runId = "old"; ended.endedAt = 6
    db.runs.old = ended
    db.ui.view = { [App.Character()] = "old" }
    T.eq(App.Current().runId, "old", "the card shows the ended run")
    T.eq(ns.Facts.Report("KeepThat", "k", 1), true, "the open run still takes facts")
    T.eq(ns.Errors.Record("boom"), true, "and errors")
    db.currentByChar[App.Character()] = "old"
    T.eq(ns.Facts.Report("KeepThat", "k", 2), false, "no open run, no facts")
end)

test("App.Start passes an async step whose line is in the log and logs it, and App.Begin makes a step for another class inapplicable", function()
    local db, env = boot()
    env.UnitClass = function() return "Hunter", "HUNTER" end
    env.KeepThatDB.global.log[#env.KeepThatDB.global.log + 1] = "[kt] version 2.5.1"
    local p = plan()
    p.requirements = { caster = { text = "This step needs a Mage.", class = { "MAGE" }, unmet = "inapplicable" } }
    p.sections[1].steps = {
        { id = "kt.v", title = "Version", action = { kind = "manual", text = "Wait." }, expect = "ok", verify = { "assertions" }, auto = true, async = true,
          assertions = { { kind = "log", source = "debug", contains = "version 2.5.1" } } },
        { id = "kt.m", title = "Mage", requires = { "caster" }, action = { kind = "manual", text = "do" }, expect = "ok", verify = { "player" } },
        { id = "kt.n", title = "Next", action = { kind = "manual", text = "do" }, expect = "ok", verify = { "player" } } }
    T.ok(App.ImportPlan(assert(ns.Codec.Encode(p))))
    db.log.enabled = true
    local run = assert(App.Start("KeepThat"))
    T.eq(run.steps["kt.v"].verdict, "pass"); T.eq(run.steps["kt.v"].attempts[1].at, "start")
    local _, _, step = App.Current(); T.eq(step.id, "kt.m", "the card skips the passed step")
    local a, st, why = App.Begin()
    T.eq(a, nil); T.eq(st.id, "kt.m"); T.eq(why, "This step needs a Mage.")
    T.eq(run.steps["kt.m"].verdict, "inapplicable")
    local _, _, nxt = App.Current(); T.eq(nxt.id, "kt.n")
    local log = table.concat(db.log.entries and (function() local t = {} for _, e in ipairs(db.log.entries) do t[#t + 1] = e.msg or tostring(e) end return t end)() or {}, "\n")
    T.ok(log:find("step kt.v pass auto at start evidence matched", 1, true), log)
    T.ok(log:find("step kt.m inapplicable: This step needs a Mage.", 1, true), log)
end)

test("a step passed at run start keeps the preamble and the section intro, and an added category's async step is judged", function()
    local db, env = boot()
    env.KeepThatDB.global.log[#env.KeepThatDB.global.log + 1] = "[kt] ready"
    local p = plan()
    p.preamble = "Use any character."
    p.categories = { { id = "one", title = "One" }, { id = "two", title = "Two" } }
    p.sections[1].intro = "This section checks the start."
    p.sections[1].steps = {
        { id = "kt.v", title = "Ready", category = "one", action = { kind = "manual", text = "Wait." }, expect = "ok", verify = { "assertions" }, auto = true, async = true,
          assertions = { { kind = "log", source = "debug", contains = "ready" } } },
        { id = "kt.n", title = "Next", category = "one", action = { kind = "manual", text = "do" }, expect = "ok", verify = { "player" } },
        { id = "kt.w", title = "Late", category = "two", action = { kind = "manual", text = "Wait." }, expect = "ok", verify = { "assertions" }, auto = true, async = true,
          assertions = { { kind = "log", source = "debug", contains = "ready" } } } }
    T.ok(App.ImportPlan(assert(ns.Codec.Encode(p))))
    local run = assert(App.Start("KeepThat", { "one" }))
    T.eq(run.steps["kt.v"].verdict, "pass")
    T.ok(App.AtStart(run), "the tester has not started yet")
    local _, ctx = App.Current()
    T.eq(App.SectionIntro(run, ctx, "kt.n"), "This section checks the start.")
    T.eq(run.steps["kt.w"].verdict, "deselected")
    App.Select("two")
    T.eq(run.steps["kt.w"].verdict, "pass", "judged when its category joined the run"); T.eq(run.steps["kt.w"].attempts[1].at, "start")
end)

-- A hand-made string can carry a field of the wrong type. The card and the evidence code index and call methods on these fields,
-- so such a plan must be refused at import, not stored and then fail on every refresh.
test("a hand-made plan with a wrong-typed field is refused at import and stored nowhere", function()
    local function mut(f) local p = plan(); f(p); return p end
    local cases = {
        mut(function(p) p.logs.debug = "x" end), mut(function(p) p.logs = "x" end), mut(function(p) p.requirements = { r = "x" } end),
        mut(function(p) p.requirements = { r = { text = 5 } } end), mut(function(p) p.handoff = 5 end), mut(function(p) p.preamble = 5 end),
        mut(function(p) p.sections[1].intro = 5 end), mut(function(p) p.sections[1].setup = 5 end), mut(function(p) p.sections[1].steps[1].setup = 5 end),
        mut(function(p) p.sections[1].steps[1].assertions[1].label = 5 end),
        mut(function(p) p.sections[1].steps[1].assertions[1].contains = 5 end),
        mut(function(p) p.sections[1].steps[1].assertions[1] = { kind = "log", source = "debug", pattern = 5 } end),
        mut(function(p) p.sections[1].steps[1].assertions[1] = { kind = "log-sequence", source = "debug", sequence = { { equals = {} } } } end),
        mut(function(p) p.sections[1].steps[1].assertions[1] = { kind = "log", source = "debug", pattern = "(unclosed" } end),
        mut(function(p) p.sections[1].steps[1].requires = "x" end),
    }
    for i, p in ipairs(cases) do
        local db = boot()
        local ok, v, err = pcall(App.ImportPlan, assert(ns.Codec.Encode(p)))
        T.ok(ok, "import raised for case " .. i .. ": " .. tostring(v))
        T.ok(v == nil and tostring(err):find("not valid"), "case " .. i .. " was accepted")
        T.ok(next(db.plans) == nil and next(db.planStore) == nil, "case " .. i .. " was stored")
    end
    boot(); T.ok(App.ImportPlan(assert(ns.Codec.Encode(plan()))), "the unchanged plan still imports")
end)
test("a plan stored before these checks cannot crash the run: a log source that is not a table reads as unreadable", function()
    local db = boot()
    local p = plan(); p.logs.debug = 5      -- as an older version stored it
    db.plans.KeepThat = { plan = p, digest = "old" }; db.planStore.old = p
    local ok, snaps = pcall(ns.Evidence.Snapshot, p, {}, p.sections[1].steps[1])
    T.ok(ok, tostring(snaps))
    T.eq((ns.Evidence.CheckLog(p.sections[1].steps[1].assertions[1], snaps, p, {})), "unverified")
end)

-- tests/fixtures/bad-pattern.ct is the string the manual check in docs/test-plan.md imports: a plan whose pattern Lua cannot read.
test("the bad-pattern string of the manual check is refused at import and stored nowhere", function()
    local f = assert(io.open("tests/fixtures/bad-pattern.ct")); local s = f:read("*a"); f:close()
    local db = boot()
    local v, err = App.ImportPlan(s)
    T.ok(v == nil and tostring(err):find("not valid"), tostring(err))
    T.ok(next(db.plans) == nil and next(db.planStore) == nil, "nothing stored")
    T.ok(tostring(err):find("text pattern that the game cannot read", 1, true), "the player is told about the pattern: " .. tostring(err))
    T.ok(tostring(err):find("The plan has a missing or wrong field", 1, true) == nil, "not the generic sentence")
end)

finish()
