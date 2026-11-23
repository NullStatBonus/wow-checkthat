local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- Loads every file the TOC lists (real Ace3 libraries included) against a stub client, then drives the
-- addon the way a player would. Catches load errors, typos and bad TOC order.
local st = H.stubClient()
test("smoke: the whole TOC loads against a stub client", function()
    H.loadToc(ns, "TestThat/TestThat_Vanilla.toc")
    T.ok(ns.addon, "AceAddon created")
end)

test("smoke: enable, import, run, export and settings through the real addon", function()
    local addon = ns.addon
    TestThatDB = nil
    addon:OnInitialize()
    addon:OnEnable()
    T.ok(addon.db.profile.card.scale == 100)
    local f = io.open("build/keepthat.wtt"); local s = f:read("*a"); f:close()
    local plan, err = ns.App.ImportPlan(s)
    T.ok(plan, err)
    local slash = _G.SlashCmdList["WTT"] or _G.SlashCmdList["WOWTESTTHAT"]
    T.ok(addon.db.global.plans.KeepThat, "plan saved in the global table")
    local lines = ns.Slash.Run("start KeepThat", { card = function() ns.Card.Show() end })
    T.ok(lines[1]:find("Started"), lines[1])
    for _ = 1, 3 do ns.Card.Refresh(); ns.App.Verdict("skip") end
    ns.Card.Refresh()
    st.combat = true; ns.Card.Refresh(); ns.Card.ApplyAppearance(); st.combat = false
    ns.Card.MakeMacro()
    T.ok(ns.App.Export())
    T.ok(ns.Log.Report():find("TestThat"))
    -- settings window tree validates against the real AceConfig registry
    local reg = LibStub("AceConfigRegistry-3.0")
    T.ok(pcall(reg.ValidateOptionsTable, reg, ns.Options.Build(), "TestThat"), "options table is valid AceConfig")
end)
test("smoke: the card says who checks the step and shows live checks and navigation", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local f = io.open("build/keepthat.wtt"); local s = f:read("*a"); f:close()
    ns.App.ImportPlan(s); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.TestThatCard
    T.ok(card.banner.text:find("YOU CONFIRM"), "manual step banner: " .. tostring(card.banner.text))
    ns.App.Verdict("pass"); ns.App.Verdict("pass")        -- s1.1, s2.1 are manual
    ns.Card.Refresh()
    T.ok(card.banner.text:find("TESTTHAT CHECKS"), "assertion step banner: " .. tostring(card.banner.text))
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
    T.ok(card.step.text:find("Step 2/"), "header shows the viewed step: " .. tostring(card.step.text))
    T.ok(card.title.text:find("Endgame"), "the earlier step is shown: " .. tostring(card.title.text))
    T.ok(card.recorded.text:find("Recorded: Pass"), card.recorded.text)
    card.redo.scripts.OnClick()
    T.ok(card.pass.shown and not card.redo.shown, "Redo reopens the step")
    card.nextBtn.scripts.OnClick()
    T.ok(card.step.text:find("Step 3/"), "forward returns to the current step: " .. tostring(card.step.text))
end)
test("smoke: importing a plan after a finished run restarts the flow", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    ns.App.Start("KeepThat")
    for _ = 1, 20 do ns.Card.Refresh(); if not select(3, ns.App.Current()) then break end; ns.App.Verdict("skip") end
    T.ok(select(3, ns.App.Current()) == nil, "first run is complete")
    ns.Card.Show(); ns.Card.Refresh()
    -- results screen: Export and a Main window button; no Reload
    local card = _G.TestThatCard
    T.ok(card.exportBtn.shown and card.mainBtn.shown, "Export results and Main window shown")
    T.ok(not card.reload.shown, "no Reload on the results screen")
    local opened
    local realOpen = ns.Options.Open
    ns.Options.Open = function(page) opened = page end
    card.mainBtn.scripts.OnClick()
    ns.Options.Open = realOpen
    T.eq(opened, nil, "Main window stays on the floating card, not the settings window")
    T.ok(card.start.shown and card.importAgain.shown, "Main window shows the start screen with Start run and Import a plan")
    T.ok(not card.resume.shown and not card.exportBtn.shown, "a finished run has nothing to resume")
    ns.App.db.ui.pendingStart = nil; ns.Card.Refresh()
    T.ok(not _G.TestThatCard.start.shown, "no Start button on the finished run")
    local f = io.open("build/dontdothat.wtt"); local s = f:read("*a"); f:close()
    ns.Card.ImportPrompt()
    local box = _G.TestThatTextBox
    box.edit:SetText(s); box.ok.scripts.OnClick()
    T.ok(_G.TestThatCard.start.shown, "Start run is offered after importing a new plan")
    T.ok(not _G.TestThatCard.resume.shown, "a finished run cannot be resumed")
    _G.TestThatCard.start.scripts.OnClick()
    local run = ns.App.Current()
    T.eq(run.addon, "DontDoThat"); T.eq(ns.App.db.ui.pendingStart, nil)
    -- an unfinished run offers Resume when another plan is imported
    f = io.open("build/keepthat.wtt"); s = f:read("*a"); f:close()
    ns.Card.ImportPrompt(); box = _G.TestThatTextBox
    box.edit:SetText(s); box.ok.scripts.OnClick()
    T.ok(_G.TestThatCard.start.shown and _G.TestThatCard.resume.shown, "Start and Resume offered")
    _G.TestThatCard.resume.scripts.OnClick()
    T.eq(ns.App.Current().addon, "DontDoThat", "resume returns to the unfinished run")
end)
test("smoke: the secure Run button is anchored to the screen only, never to the card", function()
    local sb = _G.TestThatSecureButton
    local calls = {}
    rawset(sb, "SetPoint", function(self, ...) calls[#calls + 1] = { ... } end)
    rawset(_G.UIParent, "GetEffectiveScale", function() return 1 end)
    local card = _G.TestThatCard
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
    local f = io.open("build/dontdothat.wtt"); local s = f:read("*a"); f:close()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    ns.App.db.currentByChar = {}            -- no active run
    ns.Card.Show(); _G.TestThatCard:Hide()
    ns.Card.ImportPrompt()
    local box = _G.TestThatTextBox
    box.edit:SetText(s); box.ok.scripts.OnClick()
    T.ok(_G.TestThatCard.shown, "card opened after import")
    T.eq(ns.App.db.ui.lastImport, "DontDoThat")
    -- the import screen offers the plans used before, and picking one reopens it without pasting
    ns.App.db.ui.lastImport = nil; _G.TestThatCard:Hide()
    ns.Card.ImportPrompt()
    local b = _G.TestThatTextBox
    T.ok(b.choices and #b.choices >= 1, "recent plans offered")
    b.onChoose(b.choices[1].id)
    T.ok(_G.TestThatCard.shown); T.eq(ns.App.db.ui.lastImport, "DontDoThat")
end)

test("smoke: a note stays with its step attempt", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    ns.App.Start("KeepThat"); ns.Card.Show(); ns.Card.Refresh()
    local card = _G.TestThatCard
    card.note:SetText("note for step one")
    ns.Card.Go(1)
    T.eq(card.note:GetText(), "", "moving to another step clears the draft")
end)
test("smoke: a reload request on the last step shows Reload on the results screen", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local run = ns.App.Start("KeepThat")
    for _ = 1, 20 do ns.Card.Refresh(); if not select(3, ns.App.Current()) then break end; ns.App.Verdict("skip") end
    ns.App.db.ui.shareReload = run.runId
    ns.Card.Refresh()
    T.ok(_G.TestThatCard.reload.shown, "Reload offered on the results screen")
    ns.App.db.ui.shareReload = nil; ns.Card.Refresh()
    T.ok(not _G.TestThatCard.reload.shown, "and gone once the request is cleared")
    -- a request from another run, or a stale one from before a reload, is ignored
    ns.App.db.ui.shareReload = "some-other-run"; ns.Card.Refresh()
    T.ok(not _G.TestThatCard.reload.shown)
    ns.App.Init(ns.App.db, ns.App.env)
    T.eq(ns.App.db.ui.shareReload, nil, "loading again clears a pending reload request")
end)
test("smoke: the Run button is built out of combat only and hidden by a state driver", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    ns.App.Start("KeepThat")
    local card = _G.TestThatCard
    local driven
    rawset(_G, "RegisterStateDriver", function(f, state, cond) driven = { f, state, cond } end)
    card.secure = false
    rawset(_G, "InCombatLockdown", function() return true end)
    T.ok(pcall(ns.Card.Refresh), "refresh in combat does not raise")
    T.ok(card.secure == false, "no protected frame is built in combat")
    rawset(_G, "InCombatLockdown", function() return false end)
    ns.Card.Refresh()
    T.ok(card.secure, "built after combat")
    T.ok(driven and driven[2] == "visibility" and driven[3]:find("[combat] hide", 1, true), "hidden for the whole of combat")
    rawset(_G, "RegisterStateDriver", nil)
end)

test("smoke: an auto step passes by itself, shows its countdown and waits while the card is hidden", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    local p = { kind = "plan", wtt = 1, addon = "KeepThat", title = "Auto",
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
    local card = _G.TestThatCard
    T.ok(card.banner.text:find("records the result when the checks are met"), "auto banner: " .. tostring(card.banner.text))
    T.ok(card.checks.text:find("records the result in 30 s"), "countdown: " .. tostring(card.checks.text))
    T.eq(ns.Card.AutoSettle(), nil, "nothing recorded before the line")
    KeepThatDB.global.log[#KeepThatDB.global.log + 1] = "bags opened"
    T.ok(ns.Card.AutoSettle(), "recorded when the line appears")
    local run, _, step = ns.App.Current()
    T.eq(run.steps["au.1"].verdict, "pass"); T.eq(step.id, "au.2", "card moved on")
    T.ok(card.title.text:find("Second"), "card shows the next step")
    T.ok(card.rows[1].body.text:find("TestThat records the result when the checks below are met"), "wait-event wording: " .. tostring(card.rows[1].body.text))
    card.prevBtn.scripts.OnClick()
    T.ok(card.recorded.text:find("recorded by TestThat"), "settled step is marked: " .. tostring(card.recorded.text))
    card.nextBtn.scripts.OnClick()
    -- a hidden card records nothing
    card:Hide()
    KeepThatDB.global.log[#KeepThatDB.global.log + 1] = "map opened"
    T.eq(ns.Card.AutoSettle(), nil, "hidden card records nothing")
    T.eq(select(1, ns.App.Current()).steps["au.2"].verdict, "pending")
    card.ticking = false; st.timers = {}
    ns.Card.Show()                                       -- queues the card's refresh loop
    local queued = st.timers; st.timers = {}             -- a loop that re-queues itself must not run forever
    for _, fn in ipairs(queued) do fn() end
    T.eq(select(1, ns.App.Current()).steps["au.2"].verdict, "pass", "the refresh loop settles it once the card is shown again")
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
        return { kind = "plan", wtt = 1, addon = "KeepThat", title = "G", logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
            sections = { { id = "s", title = "S", steps = steps } } }
    end
    local function log(s) KeepThatDB.global.log[#KeepThatDB.global.log + 1] = s end
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(plan(4))))); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.TestThatCard
    local function verdict(id) return select(1, ns.App.Current()).steps[id].verdict end
    -- combat: the redraw after a result must not touch the protected button
    local calls = 0
    local real = card.secure.SetAttribute
    card.secure.SetAttribute = function(self, ...) calls = calls + 1; return real(self, ...) end
    rawset(_G, "InCombatLockdown", function() return true end); log("line 1")
    T.ok(ns.Card.AutoSettle(), "recorded in combat")
    T.eq(calls, 0, "no protected SetAttribute in combat")
    rawset(_G, "InCombatLockdown", function() return false end)
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
    local p = { kind = "plan", wtt = 1, addon = "KeepThat", title = "T", logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "t.1", title = "Timed", auto = true, timeout = 5, action = { kind = "wait-event" }, expect = "e", verify = { "assertions" },
              assertions = { { kind = "log", source = "debug", contains = "never" } } },
            { id = "t.2", title = "Next", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } } } } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p)))); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.TestThatCard
    T.ok(card.banner.text:find("records the result when the checks are met"), "promise before the timeout")
    local realTime = ns.App.env.time
    ns.App.env.time = function() return (realTime and realTime() or 0) + 100 end
    ns.Card.AutoSettle()
    ns.App.env.time = realTime
    local run = select(1, ns.App.Current())
    T.eq(run.steps["t.1"].verdict, "unverified")
    ns.Card.Refresh()
    T.ok(not card.banner.text:find("records the result when the checks are met"), "no promise on the retry: " .. tostring(card.banner.text))
    T.ok(card.rows[1].body.text:find("press Pass"), "tells the player to press Pass: " .. tostring(card.rows[1].body.text))
    T.ok(not card.checks.text:find("records the result in"), "no countdown on the retry")
end)
test("smoke: a note from another step is not saved by an automatic result", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    _G.KeepThatDB = { global = { log = { "[blizzard] boot" } } }
    local p = { kind = "plan", wtt = 1, addon = "KeepThat", title = "N", logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "n.1", title = "One", auto = true, action = { kind = "wait-event" }, expect = "e", verify = { "assertions" },
              assertions = { { kind = "log", source = "debug", contains = "one" } } } } } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p)))); ns.App.Start("KeepThat")
    ns.Card.Show()
    local card = _G.TestThatCard
    card.note:SetText("belongs elsewhere"); card.noteKey = "another/step/1"   -- a collapsed refresh left it behind
    KeepThatDB.global.log[#KeepThatDB.global.log + 1] = "one"
    ns.Card.AutoSettle()
    T.eq(select(1, ns.App.Current()).steps["n.1"].attempts[1].note, nil)
end)
finish()
