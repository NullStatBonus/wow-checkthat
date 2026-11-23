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
finish()
