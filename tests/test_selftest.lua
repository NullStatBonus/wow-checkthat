local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.stubClient({})
H.plain(ns)
local App = ns.App
test("self-test plan runs end to end with its own debug log as evidence", function()
    local f = io.open("build/selftest.ct"); local s = f:read("*a"); f:close()
    local clock = 7000                            -- the facts limit is per second, so each click happens a second later
    local function facts() clock = clock + 2; return ns.Slash.Run("selftest facts", {}) end
    local env = { time = function() return clock end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end,
        IsAddOnLoaded = function(n) return n == "CheckThat" end, CheckThat = ns.Facts.API(), InCombatLockdown = function() return false end }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    assert(App.ImportPlan(s))
    local run = assert(App.Start("CheckThat"))
    T.eq(#run.order, 16)
    T.eq(#run.categories, 5); T.eq(run.cat["self.typed"], "facts"); T.eq(run.cat["self.error"], "errors")
    ns.Errors.Hook()
    -- step 1 is automatic: it waits until the player types /ct debug on, then records its own result
    App.Begin(); T.eq(App.AutoSettle(), nil, "waits for the command")
    db.log.enabled = true; App.Log("debug on")   -- player types /ct debug on
    local d = App.AutoSettle()
    T.eq(d.verdict, "pass"); T.eq(d.evidence, "matched"); T.eq(d.by, "auto")
    App.Begin(); T.eq(App.AutoSettle(), nil, "waits for the Run click")
    App.Log("status requested")                  -- the player clicks Run; CheckThat records the result itself
    local s = App.AutoSettle()
    T.eq(s.verdict, "pass"); T.eq(s.by, "auto")
    -- reload step: attempt opens, reload happens (state saved), login logs the resume line, the runner settles it
    App.Begin(); App.MarkReloaded(); App.Log("resumed run " .. run.runId .. " after load")
    local a = App.AutoSettle()
    T.eq(a.verdict, "pass"); T.eq(a.evidence, "matched"); T.eq(a.by, "auto")
    -- facts step: waits until the player types the /run line, then passes by itself
    local _, fctx, fstep = App.Current()
    T.eq(fstep.id, "self.facts"); T.eq(fstep.action.kind, "secure-macro")
    local body; for _, m in ipairs(fctx.plan.macros) do if m.id == fstep.action.macro then body = m.text end end
    T.eq(body, "/ct fact", "the Run button runs the fact command")
    App.Begin(); T.eq(App.AutoSettle(), nil, "waits for the fact")
    T.eq(ns.Slash.Run("fact", {})[1], "Reported the test fact.")  -- the player clicks Run, which runs /ct fact
    local f = App.AutoSettle()
    T.eq(f.verdict, "pass"); T.eq(f.evidence, "matched"); T.eq(f.by, "auto")
    -- typed facts: between, type, approx and a count of at least two, all judged from the reported values
    local _, tctx, tstep = App.Current()
    T.eq(tstep.id, "self.typed")
    App.Begin(); T.eq(App.AutoSettle(), nil, "waits for the facts")
    T.eq(facts()[1], "Reported the test facts.")
    local ty = App.AutoSettle()
    T.eq(ty.verdict, "pass"); T.eq(ty.evidence, "matched"); T.eq(ty.by, "auto")
    -- unit checks: each step reads the facts its own Run click reports
    for _, id in ipairs({ "self.compare", "self.text", "self.which" }) do
        local _, _, s = App.Current(); T.eq(s.id, id)
        App.Begin(); T.eq(App.AutoSettle(), nil, id .. " waits for the facts")
        T.ok(facts()[1]:find("Reported", 1, true))
        local r = App.AutoSettle()
        T.eq(r.verdict, "pass", id); T.eq(r.evidence, "matched", id); T.eq(r.by, "auto", id)
    end
    local _, _, ex = App.Current(); T.eq(ex.id, "self.exact")
    App.Begin(); T.eq(App.AutoSettle(), nil, "waits for the facts")
    facts()
    T.eq(App.AutoSettle(), nil, "a count of exactly two waits for the timeout: more could arrive")
    clock = clock + 20
    local e = App.AutoSettle()
    T.eq(e.verdict, "pass"); T.eq(e.evidence, "matched", "exactly two hits, at most three, one level, and a fact never reported"); T.eq(e.by, "auto")
    for _, id in ipairs({ "self.state", "self.api.version", "self.api.report", "self.entry" }) do
        local _, _, s = App.Current(); T.eq(s.id, id)
        App.Begin()
        local r = App.AutoSettle()
        T.eq(r.verdict, "pass", id); T.eq(r.by, "auto", id)
    end
    -- no Lua error: silence on the quiet error source is the pass
    App.Begin(); T.eq(App.AutoSettle(), nil, "silence needs the time to pass")
    clock = clock + 10
    local ne = App.AutoSettle()
    T.eq(ne.verdict, "pass"); T.eq(ne.evidence, "matched"); T.eq(ne.by, "auto")
    -- a recorded error: the command passes a message to the error handler, CheckThat records it
    local realStack = _G.debugstack; _G.debugstack = function() return "stack line" end
    App.Begin(); T.eq(App.AutoSettle(), nil, "waits for the error")
    T.ok(ns.Slash.Run("selftest error", {})[1]:find("Raised a test error", 1, true))
    local er = App.AutoSettle()
    T.eq(#db.errorStacks, 1, "the error kept one call stack")
    T.eq(er.verdict, "pass"); T.eq(er.by, "auto"); T.ok(db.errors[#db.errors]:find("CheckThat self-test error", 1, true), db.errors[#db.errors])
    _G.debugstack = realStack
    App.Begin(); T.eq(App.AutoSettle(), nil, "waits for /ct export")
    T.ok(App.Export(), "the results string is built"); App.Log("run exported " .. run.runId)
    local x = App.AutoSettle(); T.eq(x.verdict, "pass"); T.eq(x.by, "auto")
    local _, _, step = App.Current()
    T.ok(step == nil, "run complete")
    for _, row in ipairs(App.Categories()) do T.eq(row.state, "green", row.id) end
end)
test("a no-error step fails when an error arrives while it is open", function()
    local f = io.open("build/selftest.ct"); local s = f:read("*a"); f:close()
    local env = { time = function() return 7000 end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    assert(App.ImportPlan(s))
    local run = assert(App.Start("CheckThat"))
    ns.Errors.Hook()
    local _, ctx = App.Current()
    local ok = ns.Run.Begin(run, ctx, "self.noerror")
    ns.Errors.Record("Interface\\AddOns\\Other\\x.lua:1: boom")
    local a = ns.Run.Verdict(run, ctx, "self.noerror", "pass")
    T.eq(a.verdict, "fail"); T.eq(a.evidence, "contradicts")
end)

test("with BugGrabber holding the handler slot, an error during the step still fails it", function()
    local realSet = _G.seterrorhandler
    realSet(function() end)                        -- BugGrabber's handler takes the slot
    _G.seterrorhandler = function() end            -- and seterrorhandler does nothing from then on
    local f = io.open("build/selftest.ct"); local s = f:read("*a"); f:close()
    local bg = { errors = { { message = "old error", counter = 3 } } }
    local env = { time = function() return 7000 end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end, BugGrabberDB = bg }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    assert(App.ImportPlan(s))
    assert(App.Start("CheckThat"))
    T.eq(ns.Errors.HookState(), "blocked")
    T.eq(App.Trigger("self.noerror"), "step")
    App.Begin()                                    -- takes BugGrabber's counters as the starting point
    bg.errors[1].counter = 4                       -- the old error happened again: BugGrabber only counts it
    local a = App.Verdict("pass")
    T.eq(a.verdict, "fail"); T.eq(a.evidence, "contradicts"); T.ok(db.errors[#db.errors]:find("old error", 1, true), db.errors[#db.errors])
    _G.seterrorhandler = realSet
end)

test("with nothing recording errors, the no-error step cannot pass on silence", function()
    local realSet = _G.seterrorhandler
    realSet(function() end)
    _G.seterrorhandler = function() end            -- blocked, and no BugGrabber
    local f = io.open("build/selftest.ct"); local s = f:read("*a"); f:close()
    local env = { time = function() return 7000 end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    assert(App.ImportPlan(s)); assert(App.Start("CheckThat"))
    T.eq(App.Trigger("self.noerror"), "step"); App.Begin()
    local a = App.Verdict("pass")
    T.eq(a.verdict, "fail", "the step says it cannot see errors, so it does not pass"); T.ok(db.errors[#db.errors]:find("cannot see Lua errors", 1, true))
    _G.seterrorhandler = realSet
end)

finish()
