local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local App = ns.App
test("self-test plan runs end to end with its own debug log as evidence", function()
    local f = io.open("build/selftest.ct"); local s = f:read("*a"); f:close()
    local env = { time = function() return 7000 end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end,
        IsAddOnLoaded = function(n) return n == "CheckThat" end }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    assert(App.ImportPlan(s))
    local run = assert(App.Start("CheckThat"))
    T.eq(#run.order, 5)
    -- step 1 without debug on: required evidence missing => unverified
    App.Begin()
    T.eq(App.Verdict("pass").verdict, "unverified")
    App.Begin()                                  -- the card opens the retry straight away
    db.log.enabled = true; App.Log("debug on")   -- player types /ct debug on
    T.eq(App.Verdict("pass").verdict, "pass")
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
    App.Begin(); T.eq(App.Verdict("pass").verdict, "pass")
    local _, _, step = App.Current()
    T.ok(step == nil, "run complete")
end)
finish()
