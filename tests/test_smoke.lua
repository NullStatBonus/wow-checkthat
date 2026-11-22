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
    T.eq(opened, "home", "Main window opens the Home page")
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
finish()
