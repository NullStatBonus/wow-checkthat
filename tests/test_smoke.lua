local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- These flows check what is recorded, step after step: the card's pause after an automatic result (tests/test_card.lua) is off.
-- Loads every file the TOC lists (real Ace3 libraries included) against a stub client, then drives the
-- addon the way a player would. Catches load errors, typos and bad TOC order.
local st = H.stubClient()
test("smoke: the whole TOC loads against a stub client", function()
    H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
    T.ok(ns.addon, "AceAddon created")
end)

test("smoke: enable, import, run, export and settings through the real addon", function()
    local addon = ns.addon
    CheckThatDB = nil
    addon:OnInitialize()
    addon:OnEnable()
    ns.Card.HOLD = 0 -- these flows check what is recorded step after step; tests/test_card.lua covers the pause after an automatic result
    T.ok(addon.db.profile.card.scale == 100)
    T.eq(type(_G.CheckThat), "table"); T.eq(_G.CheckThat.API_VERSION, 4)
    T.eq(type(addon.db.global.facts), "table", "a save from before facts gets an empty list")
    local f = io.open("build/keepthat.ct"); local s = f:read("*a"); f:close()
    local plan, err = ns.App.ImportPlan(s)
    T.ok(plan, err)
    local slash = _G.SlashCmdList["CT"] or _G.SlashCmdList["WOWCHECKTHAT"]
    T.ok(addon.db.global.plans.KeepThat, "plan saved in the global table")
    local lines = ns.Slash.Run("start KeepThat", { card = function() ns.Card.Show() end })
    T.ok(lines[1]:find("Started"), lines[1])
    T.eq(_G.CheckThat.Report("KeepThat", "smoke", 1), true, "a fact is recorded while the run is open")
    T.eq(addon.db.global.facts[#addon.db.global.facts], "[KeepThat] smoke=1")
    LibStub("AceEvent-3.0").events:Fire("ADDON_ACTION_BLOCKED", "KeepThat", "CastSpellByName()") -- the game's event reaches CheckThat's listener (#65)
    T.ok(tostring(addon.db.global.blocked[1]):find("[KeepThat] ADDON_ACTION_BLOCKED CastSpellByName()", 1, true), tostring(addon.db.global.blocked[1]))
    T.ok(ns.Log.Report():find("Blocked actions: 1 recorded", 1, true), "the report counts it")
    for _ = 1, 3 do ns.Card.Refresh(); ns.App.Verdict("skip") end
    ns.Card.Refresh()
    st.combat = true; ns.Card.Refresh(); ns.Card.ApplyAppearance(); st.combat = false
    ns.Card.MakeMacro()
    T.ok(ns.App.Export())
    T.ok(ns.Log.Report():find("CheckThat"))
    T.ok(ns.App.End(ns.App.Current().runId))
    T.eq(_G.CheckThat.Report("KeepThat", "late", 1), false, "no fact once the run ended")
    -- settings window tree validates against the real AceConfig registry
    local reg = LibStub("AceConfigRegistry-3.0")
    T.ok(pcall(reg.ValidateOptionsTable, reg, ns.Options.Build(), "CheckThat"), "options table is valid AceConfig")
end)
test("smoke: the card says who checks the step and shows live checks and navigation", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local f = io.open("build/keepthat.ct"); local s = f:read("*a"); f:close()
    ns.App.ImportPlan(s); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.CheckThatCard
    T.ok(not card.checksHead.shown, "a manual step shows no checks heading and no banner")
    ns.App.Verdict("pass"); ns.App.Verdict("pass")        -- s1.1, s2.1 are manual
    ns.Card.Refresh()
    T.ok(card.checksHead.shown and card.checksHead.text == "CheckThat checks", "checks heading: " .. tostring(card.checksHead.text))
    T.ok(card.checks.text:find("Bag and bank hooks started"), "check label shown: " .. tostring(card.checks.text))
    T.ok(card.checks.text:find("ReadyCheck%-Waiting"), "waiting icon")
    KeepThatDB.global.log[#KeepThatDB.global.log + 1] = "[blizzard] hooked ContainerFrame"
    ns.Card.UpdateChecks()
    T.ok(card.checks.text:find("ReadyCheck%-Ready") and card.checks.text:find("All checks detected"), "ticks green: " .. tostring(card.checks.text))
    -- space for the longest state is reserved: the list is measured with the extra line before it is shown
    ns.Card.Refresh()
    local items = ns.Run.Preview(ns.App.Current(), select(2, ns.App.Current()), select(3, ns.App.Current()).id)
    T.ok(ns.Card.ChecksText(items, true):find("All checks detected"), "reserve adds the final line even before the checks are met")
    T.ok(not ns.Card.ChecksText({ { assertion = { kind = "log" }, state = "waiting" } }):find("All checks detected"), "not claimed early")
    -- back to a finished step: read-only with Redo
    card.prevBtn.scripts.OnClick()
    T.ok(card.redo.shown and not card.pass.shown, "finished step is read-only with Redo")
    T.ok(card.title.text:find("Endgame"), "the earlier step is shown: " .. tostring(card.title.text))
    T.ok(card.recorded.text:find("Recorded: Pass"), card.recorded.text)
    card.redo.scripts.OnClick()
    T.ok(card.pass.shown and not card.redo.shown, "Redo reopens the step")
    card.nextBtn.scripts.OnClick()
    T.ok(card.pass.shown and not card.redo.shown, "forward returns to the current step")
end)
test("smoke: importing a plan after a finished run restarts the flow", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    ns.App.Start("KeepThat")
    for _ = 1, 20 do ns.Card.Refresh(); if not select(3, ns.App.Current()) then break end; ns.App.Verdict("skip") end
    T.ok(select(3, ns.App.Current()) == nil, "first run is complete")
    ns.Card.Show(); ns.Card.Refresh()
    -- results screen: Export and a Main window button
    local card = _G.CheckThatCard
    T.ok(card.exportBtn.shown and card.mainBtn.shown, "Export results and Main window shown")
    local opened
    local realOpen = ns.Options.Open
    ns.Options.Open = function(page) opened = page end
    card.mainBtn.scripts.OnClick()
    ns.Options.Open = realOpen
    T.eq(opened, nil, "Main window stays on the floating card, not the settings window")
    T.ok(card.start.shown and card.importAgain.shown, "Main window shows the start screen with Start run and Import a plan")
    T.ok(not card.resume.shown and not card.exportBtn.shown, "a finished run has nothing to resume")
    ns.App.db.ui.pendingStart = nil; ns.Card.Refresh()
    T.ok(not _G.CheckThatCard.start.shown, "no Start button on the finished run")
    local f = io.open("build/dontdothat.ct"); local s = f:read("*a"); f:close()
    ns.Card.ImportPrompt()
    local box = _G.CheckThatTextBox
    box.edit:SetText(s); box.ok.scripts.OnClick()
    T.ok(_G.CheckThatCard.start.shown, "Start run is offered after importing a new plan")
    T.ok(not _G.CheckThatCard.resume.shown, "a finished run cannot be resumed")
    _G.CheckThatCard.start.scripts.OnClick()
    local run = ns.App.Current()
    T.eq(run.addon, "DontDoThat"); T.eq(ns.App.db.ui.pendingStart, nil)
    -- an unfinished run offers Resume when another plan is imported
    f = io.open("build/keepthat.ct"); s = f:read("*a"); f:close()
    ns.Card.ImportPrompt(); box = _G.CheckThatTextBox
    box.edit:SetText(s); box.ok.scripts.OnClick()
    T.ok(_G.CheckThatCard.start.shown and _G.CheckThatCard.resume.shown, "Start and Resume offered")
    _G.CheckThatCard.resume.scripts.OnClick()
    T.eq(ns.App.Current().addon, "DontDoThat", "resume returns to the unfinished run")
end)
test("smoke: the secure Run button is anchored to the screen only, never to the card", function()
    local sb = _G.CheckThatSecureButton
    local calls = {}
    rawset(sb, "SetPoint", function(self, ...) calls[#calls + 1] = { ... } end)
    rawset(_G.UIParent, "GetEffectiveScale", function() return 1 end)
    local card = _G.CheckThatCard
    for _, c in ipairs(card.copies) do
        rawset(c, "GetRight", function() return 300 end); rawset(c, "GetTop", function() return 100 end)
        rawset(c, "GetBottom", function() return 80 end); rawset(c, "GetEffectiveScale", function() return 1 end)
    end
    ns.App.Start("KeepThat")
    ns.Card.Show(); ns.Card.Refresh()
    T.ok(#calls > 0, "button was placed")
    for _, c in ipairs(calls) do T.ok(c[2] == _G.UIParent, "anchor must be UIParent") end
    -- a failing SetPoint is logged, never raised
    rawset(sb, "SetPoint", function() error("Cannot anchor protected frames to regions") end)
    T.ok(pcall(ns.Card.Refresh))
end)
test("smoke: importing a plan opens the window with a Start button", function()
    local f = io.open("build/dontdothat.ct"); local s = f:read("*a"); f:close()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    ns.App.db.currentByChar = {}            -- no active run
    ns.Card.Show(); _G.CheckThatCard:Hide()
    ns.Card.ImportPrompt()
    local box = _G.CheckThatTextBox
    box.edit:SetText(s); box.ok.scripts.OnClick()
    T.ok(_G.CheckThatCard.shown, "card opened after import")
    T.eq(ns.App.db.ui.lastImport, "DontDoThat")
    -- the import screen offers the plans used before, and picking one reopens it without pasting
    ns.App.db.ui.lastImport = nil; _G.CheckThatCard:Hide()
    ns.Card.ImportPrompt()
    local b = _G.CheckThatTextBox
    T.ok(b.choices and #b.choices >= 2, "the self-test and the recent plans offered")
    T.eq(b.choices[1].id, ns.App.BUILTIN, "the self-test comes first")
    b.onChoose(b.choices[2].id)
    T.ok(_G.CheckThatCard.shown); T.eq(ns.App.db.ui.lastImport, "DontDoThat")
end)
test("smoke: choosing the built-in self-test imports it without pasting", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil; ns.App.db.ui.lastImport = nil
    _G.CheckThatCard:Hide()
    ns.Card.ImportPrompt()
    local b = _G.CheckThatTextBox
    T.eq(b.title:GetText(), "Import a plan")
    T.eq(b.choices[1].text, "CheckThat self-test (built-in)")
    b.onChoose(b.choices[1].id)
    T.eq(b.edit:GetText(), "", "the string never shows in the box")
    T.ok(_G.CheckThatCard.shown, "the card opens"); T.eq(ns.App.db.ui.lastImport, "CheckThat")
    T.ok(_G.CheckThatCard.start.shown, "with Start run")
    T.eq(_G.CheckThatCard.title:GetText(), "CheckThat self-test")
    ns.Card.ImportPrompt(); b = _G.CheckThatTextBox
    local n = 0
    for _, ch in ipairs(b.choices) do if ch.text:find("self%-test") then n = n + 1 end end
    T.eq(n, 1, "listed once after it is imported")
    b:Hide()
end)

test("smoke: a note stays with its step attempt", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    ns.App.Start("KeepThat"); ns.Card.Show(); ns.Card.Refresh()
    local card = _G.CheckThatCard
    card.note:SetText("note for step one")
    ns.Card.Go(1)
    T.eq(card.note:GetText(), "", "moving to another step clears the draft")
end)
test("smoke: a reload request on the last step tells the player to type /reload on the results screen", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local run = ns.App.Start("KeepThat")
    for _ = 1, 20 do ns.Card.Refresh(); if not select(3, ns.App.Current()) then break end; ns.App.Verdict("skip") end
    ns.App.db.ui.shareReload = run.runId
    ns.Card.Refresh()
    T.ok(_G.CheckThatCard.context.text:find("Type /reload now", 1, true), "the results screen asks for a reload")
    ns.App.db.ui.shareReload = nil; ns.Card.Refresh()
    T.ok(not _G.CheckThatCard.context.text:find("/reload", 1, true), "and stops once the request is cleared")
    -- a request from another run, or a stale one from before a reload, is ignored
    ns.App.db.ui.shareReload = "some-other-run"; ns.Card.Refresh()
    T.ok(not _G.CheckThatCard.context.text:find("/reload", 1, true))
    ns.App.Init(ns.App.db, ns.App.env)
    T.eq(ns.App.db.ui.shareReload, nil, "loading again clears a pending reload request")
end)
test("smoke: the Run button is built out of combat only and hidden by a state driver", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    ns.App.Start("KeepThat")
    local card = _G.CheckThatCard
    card.secure = false
    st.setCombat(true)
    T.ok(pcall(ns.Card.Refresh), "refresh in combat does not raise")
    T.ok(card.secure == false, "no protected frame is built in combat")
    st.setCombat(false)
    ns.Card.Refresh()
    T.ok(card.secure, "built after combat")
    local cond = card.secure.drivers.visibility
    T.ok(cond and cond:find("[combat] hide", 1, true), "hidden for the whole of combat")
end)

test("smoke: an auto step passes by itself, shows its countdown and waits while the card is hidden", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "Auto",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "au.1", title = "First", auto = true, timeout = 30, action = { kind = "wait-event", text = "Open your bags." },
              expect = "Bags open.", verify = { "assertions" },
              assertions = { { kind = "log", source = "debug", contains = "bags opened", label = "Bags opened" } } },
            { id = "au.2", title = "Second", auto = true, action = { kind = "wait-event" },
              expect = "Map opens.", verify = { "assertions" },
              assertions = { { kind = "log", source = "debug", contains = "map opened", label = "Map opened" } } },
            { id = "au.3", title = "Third", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } } } } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p)))); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.CheckThatCard
    T.eq(card.checksHead.text, "CheckThat checks and records the result", "auto heading")
    T.ok(card.checks.text:find("records the result in 30 s"), "countdown: " .. tostring(card.checks.text))
    T.ok(card.checks.text:find("|r\n\nCheckThat records the result in 30 s", 1, true), "a blank line above the countdown: " .. tostring(card.checks.text))
    T.eq(ns.Card.AutoSettle(), nil, "nothing recorded before the line")
    KeepThatDB.global.log[#KeepThatDB.global.log + 1] = "bags opened"
    T.ok(ns.Card.AutoSettle(), "recorded when the line appears")
    local run, _, step = ns.App.Current()
    T.eq(run.steps["au.1"].verdict, "pass"); T.eq(step.id, "au.2", "card moved on")
    T.ok(card.title.text:find("Second"), "card shows the next step")
    T.ok(card.rows[2].body.text:find("CheckThat records the result when the checks below are met"), "wait-event wording: " .. tostring(card.rows[2].body.text))
    card.prevBtn.scripts.OnClick()
    T.ok(card.recorded.text:find("recorded by CheckThat"), "settled step is marked: " .. tostring(card.recorded.text))
    card.nextBtn.scripts.OnClick()
    -- a hidden card still settles an open auto step, from the loop it left running
    card:Hide()
    card.ticking = false; st.timers = {}
    ns.Card.Show(); card:Hide()                          -- queues the loop, then hides the card
    KeepThatDB.global.log[#KeepThatDB.global.log + 1] = "map opened"
    local queued = st.timers; st.timers = {}             -- a loop that re-queues itself must not run forever
    for _, fn in ipairs(queued) do fn() end
    T.eq(select(1, ns.App.Current()).steps["au.2"].verdict, "pass", "the loop settles it with the card hidden")
    local again = st.timers; st.timers = {}; for _, fn in ipairs(again) do fn() end -- next tick sees no auto step
    T.eq(card.ticking, false, "the loop stops: the card is hidden and the next step is not auto")
    ns.Card.Show()
    T.ok(card.title.text:find("Third"), "the card opens on the next step")
    T.eq(card.ticking, true, "showing the card restarts the loop")
end)
test("smoke: an auto step records nothing in combat, behind a Start screen or with the UI hidden, and keeps a typed note", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    local function plan(n)
        local steps = {}
        for i = 1, n do
            steps[i] = { id = "g." .. i, title = "Go " .. i, auto = true, action = { kind = "wait-event" }, expect = "e", verify = { "assertions" },
                assertions = { { kind = "log", source = "debug", contains = "line " .. i } } }
        end
        steps[#steps + 1] = { id = "g.end", title = "End", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } }
        return { kind = "plan", ct = 1, addon = "KeepThat", title = "G", logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
            sections = { { id = "s", title = "S", steps = steps } } }
    end
    local function log(s) KeepThatDB.global.log[#KeepThatDB.global.log + 1] = s end
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(plan(4))))); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.CheckThatCard
    local function verdict(id) return select(1, ns.App.Current()).steps[id].verdict end
    -- combat: the redraw after a result must not touch the protected button
    local calls = 0
    local real = card.secure.SetAttribute
    card.secure.SetAttribute = function(self, ...) calls = calls + 1; return real(self, ...) end
    st.setCombat(true); log("line 1")
    T.ok(ns.Card.AutoSettle(), "recorded in combat")
    T.eq(calls, 0, "no protected SetAttribute in combat")
    st.setCombat(false)
    -- a typed note is kept
    card.note:SetText("slow but fine"); log("line 2")
    ns.Card.AutoSettle()
    local run = select(1, ns.App.Current())
    T.eq(run.steps["g.2"].attempts[1].note, "slow but fine"); T.eq(card.note:GetText(), "", "box cleared like after a click")
    -- the game UI is hidden: the card is shown but not visible
    card.IsVisible = function() return false end
    log("line 3")
    T.eq(ns.Card.AutoSettle(), nil); T.eq(verdict("g.3"), "pending")
    card.IsVisible = nil
    -- another plan waits on the Start screen
    ns.App.db.ui.pendingStart = "KeepThat"
    T.eq(ns.Card.AutoSettle(), nil, "nothing recorded behind the Start screen"); T.eq(verdict("g.3"), "pending")
    ns.App.db.ui.pendingStart = nil
    T.ok(ns.Card.AutoSettle(), "records once the run is showing again"); T.eq(verdict("g.3"), "pass")
end)
test("smoke: after an automatic unverified result the card stops promising automatic recording", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "T", logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "t.1", title = "Timed", auto = true, timeout = 5, action = { kind = "wait-event" }, expect = "e", verify = { "assertions" },
              assertions = { { kind = "log", source = "debug", contains = "never" } } },
            { id = "t.2", title = "Next", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } } } } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p)))); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.CheckThatCard
    T.eq(card.checksHead.text, "CheckThat checks and records the result", "promise before the timeout")
    local realTime = ns.App.env.time
    ns.App.env.time = function() return (realTime and realTime() or 0) + 100 end
    ns.Card.AutoSettle()
    ns.App.env.time = realTime
    local run = select(1, ns.App.Current())
    T.eq(run.steps["t.1"].verdict, "unverified")
    ns.Card.Refresh()
    T.eq(card.checksHead.text, "CheckThat checks", "no promise on the retry")
    T.ok(card.rows[2].body.text:find("press Pass"), "tells the player to press Pass: " .. tostring(card.rows[2].body.text))
    T.ok(not card.checks.text:find("records the result in"), "no countdown on the retry")
end)
test("smoke: a note from another step is not saved by an automatic result", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "N", logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "n.1", title = "One", auto = true, action = { kind = "wait-event" }, expect = "e", verify = { "assertions" },
              assertions = { { kind = "log", source = "debug", contains = "one" } } } } } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p)))); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.CheckThatCard
    card.note:SetText("belongs elsewhere"); card.noteKey = "another/step/1"   -- a collapsed refresh left it behind
    KeepThatDB.global.log[#KeepThatDB.global.log + 1] = "one"
    ns.Card.AutoSettle()
    T.eq(select(1, ns.App.Current()).steps["n.1"].attempts[1].note, nil)
end)
test("smoke: the Run button shows only with a step that has commands, and is hidden again if the game shows it", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    local drivers = {}
    local realRegister, realRelease = _G.RegisterStateDriver, _G.UnregisterStateDriver
    rawset(_G, "RegisterStateDriver", function(f, state, cond) drivers[#drivers + 1] = "register " .. state; return realRegister(f, state, cond) end)
    rawset(_G, "UnregisterStateDriver", function(f, state) drivers[#drivers + 1] = "release " .. state; return realRelease(f, state) end)
    local function cmdStep(id) return { id = id, title = "With " .. id, action = { kind = "copy-slash", text = "/kt log", commands = { "/kt log" } }, expect = "e", verify = { "player" } } end
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "R", logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = { cmdStep("r.1"),
            { id = "r.2", title = "Without command", action = { kind = "manual", text = "Look." }, expect = "e", verify = { "player" } },
            cmdStep("r.3") } } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil; ns.App.db.log.enabled = true; ns.App.db.log.entries = {}
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p)))); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.CheckThatCard
    local s = card.secure
    local function hiddenLines() local n = 0; for _, e in ipairs(ns.App.db.log.entries) do if tostring(type(e) == "table" and e.msg or e):find("run button hidden", 1, true) then n = n + 1 end end; return n end
    local function logged() return hiddenLines() > 0 end
    local function gameShows() s:Show() end                                  -- what the combat state driver does
    T.ok(s.shown, "visible with a step that has commands")
    gameShows(); T.ok(s.shown, "the guard leaves it alone there"); T.ok(not logged(), "and logs nothing")
    ns.App.Verdict("pass"); ns.Card.Refresh()                                -- r.2 has no commands
    T.ok(not s.shown, "hidden on a step without commands")
    T.eq(drivers[#drivers], "release visibility", "released from the combat state driver, so the game stops showing it")
    ns.Card.Refresh(); ns.Card.Refresh()
    local n = #drivers
    ns.Card.Refresh(); T.eq(#drivers, n, "released once, not on every refresh")
    gameShows(); T.ok(not s.shown, "hidden again when the game shows it"); T.ok(logged(), "and the log says so")
    for _ = 1, 5 do gameShows() end                                          -- the state driver shows it about five times a second
    T.eq(hiddenLines(), 1, "one line for the screen, not one for each time the game shows the button")
    ns.App.Verdict("pass"); ns.Card.Refresh()                                -- r.3 has commands again
    T.ok(s.shown, "visible again with the next step that has commands")
    T.eq(drivers[#drivers], "register visibility", "the combat state driver hides it again for combat")
    T.eq(hiddenLines(), 1, "a step with commands logs nothing")
    ns.App.db.ui.pendingStart = "KeepThat"; ns.Card.Refresh()                -- the Start screen of another plan
    local before = hiddenLines()
    gameShows(); T.ok(not s.shown, "Start screen: hidden again"); T.eq(hiddenLines(), before + 1, "a new screen logs a new line")
    ns.App.db.ui.pendingStart = nil; ns.Card.Refresh()
    T.ok(s.shown, "back on the step: visible")
    ns.App.Verdict("pass"); ns.Card.Refresh()                                -- results screen, right after a step that had commands
    T.ok(select(3, ns.App.Current()) == nil, "run complete")
    gameShows(); T.ok(not s.shown, "results screen: hidden again")
    -- combat: the card never touches the protected button
    local hides = 0
    local realHide = s.Hide
    s.Hide = function(self, ...) hides = hides + 1; return realHide(self, ...) end
    s.shown = true
    st.setCombat(true)
    for _, fn in ipairs(s.hooks.OnShow) do fn(s) end
    T.eq(hides, 0, "nothing called on the button in combat")
    st.setCombat(false)
    s.Hide = nil
    rawset(_G, "RegisterStateDriver", realRegister); rawset(_G, "UnregisterStateDriver", realRelease)
end)
test("smoke: End run from the Run menu asks first, then closes the run and shows its results", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local run = ns.App.Start("KeepThat")
    ns.Card.Show(); ns.Card.Refresh()
    local card = _G.CheckThatCard
    T.ok(card.headBtn.shown, "the Run menu is on the title while a run is active")
    ns.App.Verdict("skip"); ns.Card.Refresh()
    st.popup = nil
    card.headBtn.scripts.OnClick(card.headBtn) -- the stub client has no menu API: the click asks directly
    T.ok(st.popup and st.popup.text:find("End this run%?"), "asks first")
    T.eq(run.endedAt, nil, "nothing ends before the answer")
    -- a confirmation that outlives its run ends nothing
    local stale = st.popup.OnAccept
    local run2 = ns.App.Start("KeepThat")
    stale(); T.eq(run2.endedAt, nil, "the new run is untouched")
    st.popup = nil
    ns.Card.ConfirmEnd(); st.popup.OnAccept()
    T.ok(run2.endedAt, "confirmed: the run ended")
    ns.Card.Refresh()
    T.eq(card.title.text, "Run ended")
    T.ok(card.exportBtn.shown and card.mainBtn.shown, "Export results and Main window stay")
    T.ok(not card.undo.shown and not card.prevBtn.shown and not card.resume.shown, "no Undo, back or Resume")
    T.ok(not card.headBtn.shown, "no Run menu on an ended run")
    local lines = ns.Slash.Run("end", { endRun = function() error("must not ask") end })
    T.ok(lines[1]:find("already ended"), lines[1])
    T.ok(ns.Slash.Run("pass", { verdict = function(c, n) local _, err = ns.App.Verdict(c, n); return { err } end })[1]:find("has ended"))
end)
finish()
