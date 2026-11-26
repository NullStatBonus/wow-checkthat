-- CheckThat.OnRun and CheckThat.ActiveRun: run start and end events for sibling addons (issue 171).
local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local App = ns.App

local function plan(addon)
    return { kind = "plan", ct = 1, addon = addon, title = addon .. " plan",
        sections = { { id = "s", title = "S", steps = {
            { id = "x.1", title = "One", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } },
        } } } }
end

local function boot()
    local env = { time = function() return 1000 end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end,
        InCombatLockdown = function() return false end }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    for _, a in ipairs({ "KeepThat", "DontDoThat" }) do
        ns.RunEvents.Register(a, function() end) -- an earlier test's callback must not fire in this one
        assert(App.ImportPlan(assert(ns.Codec.Encode(plan(a)))))
    end
    return db
end

local seen
local function watch(api, addon)
    return api.OnRun(addon, function(event, info)
        seen[#seen + 1] = addon .. ":" .. event .. (info.reason and (":" .. info.reason) or "")
        seen.info = info
    end)
end

test("the API is version 3 and OnRun refuses bad input without raising", function()
    boot()
    local api = ns.Facts.API()
    T.eq(api.API_VERSION, 3)
    T.eq(api.OnRun("A B", function() end), false)
    T.eq(api.OnRun("A", "not a function"), false)
    T.eq(api.OnRun(nil, function() end), false)
    T.eq(api.OnRun(("n"):rep(33), function() end), false)
    T.eq(api.OnRun("KeepThat", function() end), true)
    T.eq(api.ActiveRun("KeepThat"), nil)
    T.eq(api.ActiveRun(42), nil)
end)

test("start and end events carry the plan, digest and reason", function()
    boot(); seen = {}
    local api = ns.Facts.API(); watch(api, "KeepThat")
    local run = assert(App.Start("KeepThat"))
    T.eq(seen[1], "KeepThat:start")
    T.eq(seen.info.plan, "KeepThat plan"); T.eq(seen.info.digest, run.planDigest); T.eq(seen.info.runId, run.runId)
    T.eq(api.ActiveRun("KeepThat"), "KeepThat plan")
    T.eq(api.ActiveRun("DontDoThat"), nil)
    assert(App.End())
    T.eq(seen[2], "KeepThat:end:ended"); T.eq(#seen, 2)
    T.eq(api.ActiveRun("KeepThat"), nil)
    T.eq(App.End(), nil, "a second end does nothing")
    T.eq(#seen, 2, "end fires once")
end)

test("clearing the plan ends the run once", function()
    boot(); seen = {}
    watch(ns.Facts.API(), "KeepThat")
    App.Start("KeepThat"); assert(App.ClearPlan())
    T.eq(table.concat(seen, ","), "KeepThat:start,KeepThat:end:ended")
end)

test("a new run replaces the open one: end first, then start", function()
    boot(); seen = {}
    local api = ns.Facts.API(); watch(api, "KeepThat"); watch(api, "DontDoThat")
    App.Start("KeepThat"); App.Start("DontDoThat")
    T.eq(table.concat(seen, ","), "KeepThat:start,KeepThat:end:replaced,DontDoThat:start")
end)

test("opening an unfinished run resumes it and replaces the current one", function()
    boot(); seen = {}
    local api = ns.Facts.API(); watch(api, "KeepThat"); watch(api, "DontDoThat")
    local a = App.Start("KeepThat"); App.Start("DontDoThat")
    seen = {}
    assert(App.OpenRun(a.runId))
    T.eq(table.concat(seen, ","), "DontDoThat:end:replaced,KeepThat:start")
    seen = {}
    assert(App.OpenRun(a.runId))
    T.eq(#seen, 0, "opening the open run is no change")
end)

test("deleting the open run ends it; deleting another run does not", function()
    boot(); seen = {}
    local api = ns.Facts.API(); watch(api, "KeepThat"); watch(api, "DontDoThat")
    local a = App.Start("KeepThat"); local b = App.Start("DontDoThat")
    seen = {}
    assert(App.DeleteRun(a.runId))
    T.eq(#seen, 0, "a run that was not open")
    assert(App.DeleteRun(b.runId))
    T.eq(table.concat(seen, ","), "DontDoThat:end:deleted")
end)

test("a reload fires nothing; registering with a run open fires start once", function()
    local db = boot(); seen = {}
    App.Start("KeepThat")
    App.Init(db, App.env) -- the same saved data after /reload
    local api = ns.Facts.API()
    T.eq(api.ActiveRun("KeepThat"), "KeepThat plan")
    T.eq(#seen, 0)
    watch(api, "KeepThat")
    T.eq(table.concat(seen, ","), "KeepThat:start")
    seen = {}
    watch(ns.Facts.API(), "DontDoThat")
    T.eq(#seen, 0, "a run of another addon")
end)

test("a throwing callback leaves the run and the other callbacks alone", function()
    local db = boot(); seen = {}
    local api = ns.Facts.API()
    api.OnRun("KeepThat", function(event) if event == "end" then error("boom", 0) end end)
    watch(api, "DontDoThat")
    local a = App.Start("KeepThat")
    T.ok(not a.endedAt)
    T.ok(App.End(), "the run ends")
    T.ok(a.endedAt)
    App.Start("DontDoThat"); T.eq(seen[1], "DontDoThat:start")
    api.OnRun("KeepThat", function() error("start boom", 0) end)
    App.Start("KeepThat")
    local found
    for _, e in ipairs(db.errors) do if e:find("run callback: start boom", 1, true) then found = true end end
    T.ok(found, "an error raised while a run is open is listed")
end)

test("the info table is a copy", function()
    boot(); seen = {}
    local api = ns.Facts.API(); watch(api, "KeepThat")
    local run = App.Start("KeepThat")
    local first = seen.info
    first.plan = "changed"; first.digest = "x"
    App.End()
    T.ok(seen.info ~= first, "each call gets its own table")
    T.eq(first.reason, nil, "a later call does not change the earlier table")
    T.eq(seen.info.plan, "KeepThat plan"); T.eq(seen.info.digest, run.planDigest)
end)

finish()
