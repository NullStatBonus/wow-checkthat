local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local App = ns.App
test("self-test plan runs end to end with its own debug log as evidence", function()
    local f = io.open("build/selftest.wtt"); local s = f:read("*a"); f:close()
    local env = { time = function() return 7000 end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end,
        IsAddOnLoaded = function(n) return n == "TestThat" end }
    local db = {}
    env.TestThatDB = { global = db }
    App.Init(db, env)
    assert(App.ImportPlan(s))
    local run = assert(App.Start("TestThat"))
    T.eq(#run.order, 4)
    -- step 1 without debug on: required evidence missing => unverified
    App.Begin()
    T.eq(App.Verdict("pass").verdict, "unverified")
    App.Begin()                                  -- the card opens the retry straight away
    db.log.enabled = true; App.Log("debug on")   -- player types /wtt debug on
    T.eq(App.Verdict("pass").verdict, "pass")
    App.Begin(); App.Log("status requested")
    T.eq(App.Verdict("pass").verdict, "pass")
    -- reload step: attempt opens, reload happens (state saved), login logs the resume line
    App.Begin(); App.MarkReloaded(); App.Log("resumed run " .. run.runId .. " after load")
    local a = App.Verdict("pass")
    T.eq(a.verdict, "pass"); T.eq(a.evidence, "matched")
    App.Begin(); T.eq(App.Verdict("pass").verdict, "pass")
    local _, _, step = App.Current()
    T.ok(step == nil, "run complete")
end)
finish()
