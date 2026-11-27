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
test("version prints the addon version and reports it as a number", function()
    local list, open = {}, { v = true }
    ns.Facts.Bind(list, function() return 1 end, function() return open.v end)
    ns.version = "0.17.3"
    T.eq(run("version")[1], "CheckThat 0.17.3")
    T.eq(list[1], "[CheckThat] version=1703")
    ns.version = "1.2.3"; run("version")
    T.eq(list[2], "[CheckThat] version=10203")
    ns.version = "unknown"
    T.eq(run("version")[1], "CheckThat unknown")
    T.eq(#list, 2, "an unknown version reports no fact")
    open.v = false; ns.version = "0.17.0"
    T.eq(run("version")[1], "CheckThat 0.17.0", "it prints with no run open")
    T.ok(run("version now")[1]:find("takes no arguments"), "an argument is refused")
    T.eq(#list, 2)
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


test("start takes the addon name in any case and knows the addons Plan.SLASH lists", function()
    ns.App.Init({}, { time = function() return 1 end, UnitName = function() return "T" end, GetRealmName = function() return "R" end })
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "t", sections = { { id = "s", title = "S", steps = {
        { id = "a", title = "A", action = { kind = "manual", text = "x" }, expect = "e", verify = { "player" } } } } } }
    ns.App.db.plans.KeepThat = { plan = p, digest = "d" }
    T.ok(run("start keepthat")[1]:find("^Started KeepThat"), "lower case")
    T.ok(run("start KEEPTHAT")[1]:find("^Started KeepThat"), "upper case")
    T.ok(run("start Nothing")[1]:find("Usage"))
    -- the list is Plan.SLASH, not a copy: an addon added there is accepted with no second edit
    ns.Plan.SLASH.NewThat = { ["/nt"] = true }
    T.finally(function() ns.Plan.SLASH.NewThat = nil end)
    T.ok(not run("start newthat")[1]:find("Usage"), "an addon in Plan.SLASH is accepted")
end)

test("a slash verdict is worded through L[], each word on its own", function()
    T.eq(ns.Slash.VerdictLine({ verdict = "pass", evidence = "matched" }), "Step pass (matched).")
    T.eq(ns.Slash.VerdictLine({ verdict = "fail", evidence = "contradicts" }), "Step fail (contradicts).")
    T.eq(ns.Slash.VerdictLine({ verdict = "skip" }), "Step skip.")
    local was = {}
    for _, k in ipairs({ "Step %s (%s).", "Step %s.", "pass", "matched" }) do was[k] = rawget(ns.L, k) end
    T.finally(function() for k, v in pairs(was) do ns.L[k] = v end; for _, k in ipairs({ "Step %s (%s).", "Step %s.", "pass", "matched" }) do if was[k] == nil then rawset(ns.L, k, nil) end end end)
    ns.L["Step %s (%s)."], ns.L["Step %s."], ns.L["pass"], ns.L["matched"] = "Schritt %s [%s].", "Schritt %s!", "bestanden", "gefunden"
    T.eq(ns.Slash.VerdictLine({ verdict = "pass", evidence = "matched" }), "Schritt bestanden [gefunden].", "a translation owns the whole sentence, brackets too")
    T.eq(ns.Slash.VerdictLine({ verdict = "pass" }), "Schritt bestanden!")
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
test("categories escapes a bar in a title, as the other chat lines do", function()
    local r = withRun({ "bank" })
    r.categories[1].title = "Bank |cffff0000red|r"
    local out = run("categories")
    T.eq(out[1], "Bank ||cffff0000red||r (bank): untested, 0 passed, 0 failed, 2 open", "chat shows the title as typed")
    T.eq(ns.App.CategoryLine(ns.App.Categories()[1]):sub(1, 9), "Bank |cff", "the line for a tooltip keeps the raw text")
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
test("rerun failed asks with the count and says so when nothing failed", function()
    withRun({ "bank" })
    T.eq(run("rerun failed")[1], "No step has failed or is unverified.")
    called.confirmRerun = nil
    ns.App.Begin(); ns.App.Verdict("fail", "x")
    T.eq(#run("rerun failed"), 0); T.eq(called.confirmRerun[1], "failed"); T.eq(called.confirmRerun[2], 1)
    T.eq(called.confirmRerun[3], "failed and unverified steps")
    T.ok(run("rerun")[1]:find("Usage: /ct rerun <category> or /ct rerun failed.", 1, true))
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
test("census starts, refuses in combat, says when busy, and rejects arguments", function()
    deps.census = function() return "started" end
    T.eq(run("census")[1], "Client census started. Wait for the completion message before you reload or log out.")
    deps.census = function() return "busy" end
    T.eq(run("census")[1], "A client census is already running.")
    deps.census = function() return "combat" end
    T.eq(run("census")[1], "Run /ct census after combat ends.")
    called.census = nil
    deps.census = function() called.census = true; return "started" end
    T.ok(run("census now")[1]:find("takes no arguments"), "an argument is refused")
    T.ok(not called.census, "and nothing starts")
    local h = run("help diagnostics")[1]
    T.ok(h:find("/ct census (record the names available in this game session)", 1, true), h)
    deps.census = nil
end)

test("a failed census tells the player in chat and the saved census stays", function()
    local handler
    ns.Slash.Register({ RegisterChatCommand = function(_, name, fn) if name == "ct" then handler = fn end end })
    local census0, print0, said = ns.Census, ns.Slash.Print, {}
    local onDone, onFail
    ns.Census = { Start = function(d, f) onDone, onFail = d, f; return "started" end }
    ns.Slash.Print = function(s) said[#said + 1] = s end
    handler("census")
    T.ok(onFail, "the failure callback is passed")
    onFail()
    ns.Census, ns.Slash.Print = census0, print0
    T.eq(said[#said], "The client census could not read the game's names. The saved census is unchanged.")
end)

finish()
