-- CheckThat.Entry and the auto step "call" field (issue 97).
local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local App = ns.App

local function plan(call, expectLine)
    return { kind = "plan", ct = 1, addon = "KeepThat", title = "KT",
        logs = { facts = { global = "CheckThatDB", path = "global.facts", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "kt.1", title = "Call", action = { kind = "manual", text = "t" }, expect = "e", auto = true, call = call,
              verify = { "assertions" }, assertions = { { kind = "log", source = "facts", equals = expectLine } } },
        } } } }
end

local combat = false
local function boot(p)
    combat = false
    local env = { time = function() return 1000 end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end,
        InCombatLockdown = function() return combat end }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    return db
end
local function start(p)
    local db = boot(p)
    assert(App.ImportPlan(assert(ns.Codec.Encode(p))))
    return db, assert(App.Start("KeepThat"))
end
local calls
local function register()
    calls = 0
    local api = ns.Facts.API()
    T.eq(api.Entry("KeepThat", "add", function(a, b) calls = calls + 1; return a + b end), true)
    T.eq(api.Entry("KeepThat", "boom", function() error("bad input", 0) end), true)
    return api
end

test("the public table has Entry and API version 2, and Entry refuses bad input", function()
    local db = boot(plan({ addon = "KeepThat", entry = "add" }, "x"))
    local api = ns.Facts.API()
    T.eq(api.API_VERSION, 2)
    T.eq(api.Entry("A B", "x", function() end), false)
    T.eq(api.Entry("A", "x", "not a function"), false)
    T.eq(api.Entry("A", ("n"):rep(49), function() end), false)
    T.eq(api.Entry("A", "ok.name-1", function() end), true)
end)

test("an auto step calls its entry when it opens and passes from the fact line", function()
    local p = plan({ addon = "KeepThat", entry = "add", args = { 2, 3 } }, "[KeepThat] entry.add=5")
    local db = boot(p); register()
    assert(App.ImportPlan(assert(ns.Codec.Encode(p)))); assert(App.Start("KeepThat"))
    T.eq(calls, 0)
    App.Begin()
    T.eq(calls, 1); T.eq(db.facts[1], "[KeepThat] entry.add=5")
    local a = App.AutoSettle()
    T.eq(a.verdict, "pass"); T.eq(a.by, "auto")
end)

test("a wrong return leaves the step unsettled and the fact line shows the value", function()
    local p = plan({ addon = "KeepThat", entry = "add", args = { 2, 3 } }, "[KeepThat] entry.add=6")
    local db = boot(p); register()
    assert(App.ImportPlan(assert(ns.Codec.Encode(p)))); assert(App.Start("KeepThat"))
    App.Begin()
    T.eq(db.facts[1], "[KeepThat] entry.add=5"); T.eq(App.AutoSettle(), nil)
end)

test("an unregistered name, a throw and a call in combat are reported, not run", function()
    local p = plan({ addon = "KeepThat", entry = "nope" }, "x")
    local db = boot(p); register()
    assert(App.ImportPlan(assert(ns.Codec.Encode(p)))); assert(App.Start("KeepThat"))
    App.Begin(); T.eq(db.facts[1], "[KeepThat] entry.nope=not registered")
    T.eq(ns.Entries.Outcome({ addon = "KeepThat", entry = "boom" }), "threw: bad input")
    combat = true
    local before = calls
    T.eq(ns.Entries.Outcome({ addon = "KeepThat", entry = "add", args = { 1, 1 } }), "refused: in combat")
    T.eq(calls, before, "the entry did not run")
end)

test("an entry registers while a run is open, as after a reload that keeps the run", function()
    local p = plan({ addon = "KeepThat", entry = "add" }, "x")
    boot(p); App.ImportPlan(assert(ns.Codec.Encode(p))); App.Start("KeepThat")
    T.eq(ns.Facts.API().Entry("KeepThat", "late", function() end), true)
    T.eq(ns.Entries.Has("KeepThat", "late"), true)
end)

test("an attempt that stays open across a reload does not call the entry again", function()
    local p = plan({ addon = "KeepThat", entry = "add", args = { 1, 1 } }, "[KeepThat] entry.add=2")
    local db = boot(p); register()
    assert(App.ImportPlan(assert(ns.Codec.Encode(p)))); assert(App.Start("KeepThat"))
    App.Begin(); App.Begin()
    T.eq(calls, 1)
end)

test("plan validation: call needs an auto step, text names and literal arguments", function()
    local function errs(call, auto)
        local p = plan(call, "x"); p.sections[1].steps[1].auto = auto
        local e = ns.Plan.Validate(p); return table.concat(e, "; ")
    end
    T.ok(errs({ addon = "KeepThat", entry = "add", args = { 1, "a", true } }, true) == "", "valid call")
    T.ok(errs({ addon = "KeepThat", entry = "add" }, nil):find("call needs auto", 1, true))
    T.ok(errs({ addon = "KeepThat" }, true):find("call needs addon and entry", 1, true))
    T.ok(errs({ addon = "KeepThat", entry = "add", args = { {} } }, true):find("call arg 1", 1, true))
    T.ok(errs({ addon = "KeepThat", entry = "add", extra = 1 }, true):find("unknown field extra", 1, true))
end)

test("a 42 character entry name records its fact, and a longer one is refused", function()
    local p = plan({ addon = "KeepThat", entry = ("n"):rep(42) }, "x")
    local db = boot(p)
    T.eq(ns.Facts.API().Entry("KeepThat", ("n"):rep(42), function() return 1 end), true)
    T.eq(ns.Facts.API().Entry("KeepThat", ("n"):rep(43), function() return 1 end), false)
    assert(App.ImportPlan(assert(ns.Codec.Encode(p)))); assert(App.Start("KeepThat"))
    App.Begin()
    T.eq(db.facts[1], "[KeepThat] entry." .. ("n"):rep(42) .. "=1")
    local bad = plan({ addon = "KeepThat", entry = ("n"):rep(43) }, "x")
    T.ok(table.concat(ns.Plan.Validate(bad), "; "):find("entry is 1 to 42", 1, true))
end)

test("when the game cannot say whether the player is in combat, no entry runs", function()
    local p = plan({ addon = "KeepThat", entry = "add", args = { 1, 1 } }, "x")
    local env = { time = function() return 1000 end, GetBuildInfo = function() return "1.15.7", "1", "x", 11507 end,
        UnitName = function() return "T" end, GetRealmName = function() return "R" end }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    register()
    T.eq(ns.Entries.Outcome({ addon = "KeepThat", entry = "add", args = { 1, 1 } }), "refused: in combat")
    T.eq(calls, 0)
    env.InCombatLockdown = function() error("broken") end
    T.eq(ns.Entries.Outcome({ addon = "KeepThat", entry = "add", args = { 1, 1 } }), "refused: in combat")
    env.InCombatLockdown = function() return nil end   -- the game's own "not in combat" answer on older clients
    T.eq(ns.Entries.Outcome({ addon = "KeepThat", entry = "add", args = { 1, 1 } }), "2")
end)

test("a malformed call is refused before dispatch, in the dispatcher and in the validator", function()
    boot(plan({ addon = "KeepThat", entry = "add" }, "x")); register()
    local before = calls
    T.eq(ns.Entries.Outcome({ addon = "KeepThat", entry = "add", args = { a = 1 } }), "invalid call")
    T.eq(ns.Entries.Outcome({ addon = "KeepThat", entry = "add", args = { { 1 }, 2 } }), "invalid call")
    T.eq(ns.Entries.Outcome({ addon = "KeepThat", entry = "add", args = { 1, nil, 3 } }), "invalid call")
    T.eq(ns.Entries.Outcome({ addon = {}, entry = "add" }), "invalid call")
    T.eq(calls, before, "nothing ran")
    local named = plan({ addon = "KeepThat", entry = "add", args = { a = 1 } }, "x")
    T.ok(table.concat(ns.Plan.Validate(named), "; "):find("call args must be a list", 1, true))
end)

finish()
