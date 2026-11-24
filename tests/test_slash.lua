local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)

local called = {}
local deps = setmetatable({ verdict = function(c, n) called.verdict = { c, n }; return { "ok" } end }, { __index = function(_, k)
    return function(...) called[k] = { ... } end end })
local function run(s) return ns.Slash.Run(s, deps) end
test("bare command opens the card; settings pages validated", function()
    run(""); T.ok(called.card)
    run("settings plans"); T.eq(called.open[1], "plans")
    T.ok(run("settings nowhere")[1]:find("Pages:"))
end)
test("get and set share the validators; bad input writes nothing", function()
    T.ok(run("set card.scale 120")[1]:find("120"))
    T.ok(run("set card.scale 999")[1]:find("accepts"))
    T.eq(ns.Settings.Get("card.scale"), 120)
    T.ok(run("set card.scale")[1]:find("Usage"))
    T.ok(run("set card.scale 1 2")[1]:find("Usage"))
    T.ok(run("get card.scale extra")[1]:find("Usage"))
    T.ok(run("get card.scale")[1]:find("120"))
    T.ok(run("get bogus")[1]:find("Unknown key"))
end)
test("fact reports the test fact while a run is open and says so otherwise", function()
    local list, open = {}, { v = false }
    ns.Facts.Bind(list, function() return 1 end, function() return open.v end)
    T.ok(run("fact")[1]:find("No run is open"), "no run")
    T.eq(#list, 0)
    open.v = true
    T.eq(run("fact")[1], "Reported the test fact.")
    T.eq(list[1], "[CheckThat] selftest=1")
    T.ok(run("fact now")[1]:find("takes no arguments"), "an argument is refused")
    T.eq(#list, 1)
    for _ = 1, 40 do run("fact") end
    T.eq(run("fact")[1], "The test fact was not recorded.", "over the rate limit")
    T.ok(run("help diagnostics")[1]:find("/ct fact", 1, true), "help names the command")
end)
test("help topics and status", function()
    T.ok(run("help")[1]:find("Help:"))
    T.ok(run("help diagnostics")[1]:find("log clear"))
    T.ok(run("help nope")[1]:find("Topics"))
    T.ok(#run("status settings") == 4)
end)
test("debug and log commands", function()
    run("debug on"); T.eq(called.setDebug[1], true)
    run("debug off"); T.eq(called.setDebug[1], false)
    T.ok(run("debug maybe")[1]:find("Usage"))
    run("log"); T.ok(called.report)
    run("log clear"); T.ok(called.confirmClear)
    T.ok(run("log wipe")[1]:find("Usage"))
end)
test("surplus input is rejected without effect", function()
    called.reload = nil
    T.ok(run("reload now")[1]:find("takes no arguments")); T.ok(called.reload == nil)
    T.ok(run("undo twice")[1]:find("takes no arguments"))
    T.ok(run("settings plans extra")[1]:find("Pages:"))
    T.ok(run("help appearance extra")[1]:find("Topics:"))
end)
test("back and next move through the steps", function()
    called.card = nil
    local before = ns.App.Goto
    local moved = {}
    ns.App.Goto = function(d) moved[#moved + 1] = d; return 1 end
    run("back"); run("next")
    ns.App.Goto = before
    T.eq(moved[1], -1); T.eq(moved[2], 1)
    T.ok(run("back now")[1]:find("takes no arguments"))
end)
test("runner commands", function()
    run("pass nice work"); T.eq(called.verdict[1], "pass"); T.eq(called.verdict[2], "nice work")
    run("partial slow but works"); T.eq(called.verdict[1], "partial"); T.eq(called.verdict[2], "slow but works")
    run("import"); T.ok(called.importPrompt)
    run("export"); T.ok(called.export)
    run("macro"); T.ok(called.macro)
    run("reload"); T.ok(called.reload)
    T.ok(run("start Nothing")[1]:find("Usage"))
    T.ok(run("zzz")[1]:find("Unknown command"))
end)

test("start shows the card and undo refreshes it", function()
    ns.App.Init({}, { time = function() return 1 end, UnitName = function() return "T" end, GetRealmName = function() return "R" end })
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "t", sections = { { id = "s", title = "S", steps = {
        { id = "a", title = "A", action = { kind = "manual", text = "x" }, expect = "e", verify = { "player" } } } } } }
    ns.App.db.plans.KeepThat = { plan = p, digest = "d" }
    called.card = nil
    run("start KeepThat"); T.eq(called.card[1], true, "show, not toggle")
    ns.App.Begin(); ns.App.Verdict("skip")
    called.card = nil
    T.eq(run("undo")[1], "Undone."); T.eq(called.card[1], true, "card refreshed after undo")
    called.card = nil
    T.eq(run("undo")[1], "Nothing to undo."); T.ok(called.card == nil)
end)


test("text from a plan is escaped for chat", function()
    T.eq(ns.Slash.Esc("a|cffff0000b|r"), "a||cffff0000b||r")
    T.eq(ns.Slash.Esc("plain"), "plain")
end)

test("registers /ct and /checkthat with one handler, and no other command", function()
    local handlers = {}
    local fake = { db = { profile = {} }, RegisterChatCommand = function(_, name, fn) handlers[name] = fn end }
    ns.Slash.Register(fake)
    T.ok(handlers.ct and handlers.checkthat, "both registered")
    T.eq(handlers.ct, handlers.checkthat, "the same handler")
    local n = 0
    for _ in pairs(handlers) do n = n + 1 end
    T.eq(n, 2, "nothing else is registered")
end)
test("end asks through the card when a run can end", function()
    local App = ns.App
    local was = App.CanEnd
    called.endRun = nil
    App.CanEnd = function() return {} end
    T.eq(#run("end"), 0); T.ok(called.endRun, "the shared confirmation runs")
    called.endRun = nil
    App.CanEnd = function() return nil, "There is no run." end
    T.ok(run("end")[1]:find("no run")); T.ok(called.endRun == nil, "nothing is asked without a run")
    T.ok(run("end now")[1]:find("takes no arguments"))
    App.CanEnd = was
    T.ok(run("help runs")[1]:find("/ct end", 1, true))
end)
-- Category commands
local function withRun(picks)
    local env = { time = function() return 1000 end, GetBuildInfo = function() return "1.15.7", "63000", "x", 11507 end,
        UnitName = function() return "Tester" end, GetRealmName = function() return "Realm" end }
    local db = {}
    ns.App.Init(db, env)
    local function s(id) return { id = id, title = id, action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } } end
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "KT", sections = {
        { id = "bank", title = "Bank", steps = { s("b1"), s("b2") } }, { id = "mail", title = "Mail", steps = { s("m1") } } } }
    ns.App.ImportPlan(assert(ns.Codec.Encode(p)))
    return assert(ns.App.Start("KeepThat", picks)), db
end
test("categories lists each category with a state word and counts", function()
    withRun({ "bank" })
    local out = run("categories")
    T.eq(out[1], "Bank (bank): untested, 0 passed, 0 failed, 2 open"); T.eq(out[2], "Mail (mail): not picked")
    T.eq(out[3], "Overall: untested, 0 passed, 0 failed, 2 open")
    T.ok(run("categories now please")[1]:find("takes no arguments"), "surplus input is refused")
end)
test("run shows a category or a step and reports a bad name without changing the run", function()
    called.card = nil
    withRun({ "bank" })
    T.ok(run("run")[1]:find("Usage: /ct run"), "no name")
    T.ok(run("run bank mail")[1]:find("Usage: /ct run"), "two names")
    T.ok(run("run nothing")[1]:find("no category or step called nothing"))
    T.eq(called.card, nil, "the card does not open for a bad name")
    T.eq(run("run mail")[1], "Showing step m1."); T.ok(called.card, "the card is shown")
    T.ok(run("categories")[2]:find("Mail (mail): untested", 1, true), "run added the category")
    T.eq(run("RUN b2")[1], "Showing step b2.", "a step by id")
end)
test("rerun reopens a category and refuses names it cannot", function()
    withRun({ "bank" })
    T.ok(run("rerun")[1]:find("Usage: /ct rerun"))
    T.ok(run("rerun mail")[1]:find("not part of this run"))
    T.ok(run("rerun zzz")[1]:find("no category called zzz"))
    T.ok(run("rerun bank")[1]:find("Nothing to reopen in Bank", 1, true), "no result to reopen: no question")
    called.confirmRerun = nil
    local r = withRun({ "bank" }); ns.App.Begin(); ns.App.Verdict("pass")
    T.eq(#run("rerun bank"), 0); T.eq(called.confirmRerun[1], "bank"); T.eq(called.confirmRerun[2], 1); T.eq(called.confirmRerun[3], "Bank")
    T.eq(r.steps.b1.verdict, "pass", "the command only asks: nothing reopened yet")
end)
test("category commands refuse an ended run", function()
    local r = withRun()
    ns.App.End(r.runId)
    T.eq(run("run bank")[1], "This run has ended.")
    T.eq(run("rerun bank")[1], "This run has ended.")
end)
test("help runs names the category commands", function()
    local h = run("help runs")[1]
    T.ok(h:find("/ct categories", 1, true) and h:find("/ct rerun", 1, true), h)
end)

finish()
