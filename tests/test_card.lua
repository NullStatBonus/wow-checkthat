local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- The card's layout and menu, driven through the real addon against the stub client.
local st = H.stubClient()
H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
CheckThatDB = nil
ns.addon:OnInitialize(); ns.addon:OnEnable()

local LONG = "An extremely long title that cannot possibly fit inside the minimized card without being cut"

-- Imports the sample plan and starts a run; titles are then replaced in the stored plan.
local function startRun(title)
    local f = io.open("build/keepthat.ct"); local s = f:read("*a"); f:close()
    local plan = assert(ns.App.ImportPlan(s))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    plan.title = title or plan.title
    local run = assert(ns.App.Start("KeepThat"))
    ns.Card.Show()
    return run, plan, _G.CheckThatCard
end
local function collapse(on) ns.addon.db.profile.card.collapsed = on; ns.Card.Refresh() end

test("a long step title stays one line in the collapsed card and two in the expanded one", function()
    local run, plan, card = startRun()
    plan.sections[1].steps[1].title = LONG
    collapse(true)
    T.eq(card.title.calls.SetWidth[1], 256, "collapsed width")
    T.eq(card.title.calls.SetMaxLines[1], 1, "collapsed: one line")
    T.eq(card.title.calls.SetWordWrap[1], false, "collapsed: no wrap, so the game cuts it with an ellipsis")
    collapse(false)
    T.eq(card.title.calls.SetWidth[1], 356, "expanded width")
    T.eq(card.title.calls.SetMaxLines[1], 2, "expanded: two lines")
    T.eq(card.title.calls.SetWordWrap[1], true)
end)

test("the collapsed card shows the full step title on hover", function()
    local run, plan, card = startRun()
    plan.sections[1].steps[1].title = LONG
    local shown
    _G.GameTooltip = { SetOwner = function() end, SetText = function(_, t) shown = t end, Show = function() end, Hide = function() shown = nil end }
    collapse(true)
    T.ok(card.titleHit.shown, "hover area over the title")
    card.titleHit.scripts.OnEnter(card.titleHit)
    T.eq(shown, LONG)
    card.titleHit.scripts.OnLeave(card.titleHit)
    T.eq(shown, nil, "tooltip hides")
    collapse(false)
    T.ok(not card.titleHit.shown, "no hover area in the expanded card")
    _G.GameTooltip = nil
end)

test("the collapsed counter sits left of the collapse button and shows the current step", function()
    local run, plan, card = startRun()
    collapse(true)
    local c = card.step.calls.SetPoint
    T.ok(c[1] == "RIGHT" and c[2] == card.collapse and c[3] == "LEFT", "anchored to the collapse button")
    T.eq(card.step.text, ("%d/%d"):format(run.current, #run.order))
    ns.App.Goto(1); collapse(true)
    T.eq(card.step.text, ("%d/%d"):format(run.current, #run.order), "follows the viewed step")
    collapse(false)
    c = card.step.calls.SetPoint
    T.ok(c[2] == card.prevBtn, "expanded: left of the step buttons")
end)

local function menuApi()
    local made = {}
    _G.MenuUtil = { CreateContextMenu = function(owner, gen)
        made.items = {}
        gen(owner, { CreateButton = function(_, text, fn) made.items[#made.items + 1] = { text, fn } end })
    end }
    return made
end

test("the Run control shows while a run is active and says Run with an arrow", function()
    local run, plan, card = startRun()
    T.ok(card.headBtn.shown and card.headBtn.label.text == "Run", "a visible Run control")
    T.ok(card.headBtn.arrow and card.headBtn.calls.SetHighlightTexture, "dropdown arrow and hover highlight")
    T.eq(card.head.text, "CheckThat", "the label is no longer a heading that hides the menu")
    local c = card.headBtn.calls.SetPoint
    T.ok(c[1] == "LEFT" and c[2] == card.head, "centered on the title line, not at a fixed offset")
    ns.App.End(run.runId); ns.Card.Refresh()
    T.ok(not card.headBtn.shown, "no menu on an ended run")
end)

test("the Run menu lists Import, End run and Clear plan in that order", function()
    local run, plan, card = startRun()
    local made = menuApi()
    card.headBtn.scripts.OnClick(card.headBtn)
    T.eq(#made.items, 3)
    T.eq(made.items[1][1], "Import..."); T.eq(made.items[2][1], "End run..."); T.eq(made.items[3][1], "Clear plan...")
    _G.MenuUtil = nil
end)

test("Import in the Run menu opens the import box and leaves the run alone", function()
    local run, plan, card = startRun()
    local made = menuApi()
    local opened
    local prompt = ns.Export.Prompt
    ns.Export.Prompt = function(title) opened = title end
    card.headBtn.scripts.OnClick(card.headBtn)
    made.items[1][2]()
    ns.Export.Prompt = prompt; _G.MenuUtil = nil
    T.ok(opened and opened:find("Paste a plan string"), "the import box opened")
    T.eq(run.endedAt, nil, "the run is unchanged")
end)

test("Clear plan asks first, naming the plan, then ends the run and forgets the plan", function()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end -- the stub client has no settings window
    local run, plan, card = startRun("50% Plan")
    local made = menuApi()
    card.headBtn.scripts.OnClick(card.headBtn)
    st.popup = nil
    made.items[3][2]()
    T.ok(st.popup and st.popup.text:find("50%% Plan", 1, true), "names the plan, with % kept safe for the dialog")
    T.ok(st.popup.text:find("results stay for export", 1, true), "says results are kept")
    T.eq(run.endedAt, nil, "nothing happens before the answer")
    T.ok(ns.App.db.plans.KeepThat, "the plan stays until the answer")
    st.popup.OnAccept()
    T.ok(run.endedAt, "the run ended")
    T.eq(ns.App.db.plans.KeepThat, nil, "the plan is forgotten")
    ns.Card.Refresh()
    T.eq(card.title.text, "Run ended"); T.ok(card.exportBtn.shown, "Export results stays")
    _G.MenuUtil = nil
end)

test("Clear plan with no dialog changes nothing", function()
    local run, plan, card = startRun()
    local popups = _G.StaticPopup_Show
    _G.StaticPopup_Show = nil
    ns.Card.ConfirmClear()
    _G.StaticPopup_Show = popups
    T.eq(run.endedAt, nil); T.ok(ns.App.db.plans.KeepThat)
end)

local function importAgain() local f = io.open("build/keepthat.ct"); local s = f:read("*a"); f:close(); return assert(ns.App.ImportPlan(s)) end

test("the start screen stays full width and keeps its text inside, even over a collapsed run", function()
    local run, plan, card = startRun()
    collapse(true)
    T.eq(card.calls.SetWidth[1], 280, "a collapsed run is narrow")
    importAgain() -- a new plan takes focus: the start screen shows
    ns.Card.Refresh()
    T.eq(card.calls.SetWidth[1], 380, "the start screen is full width")
    T.ok(card.start.shown, "Start run is visible")
    T.eq(card.title.text, "KeepThat sample test plan", "the plan title is the heading")
    collapse(false)
end)

test("the start screen shows the plan title, the step count under it, and the full title on hover", function()
    local run, plan, card = startRun()
    local p = importAgain()
    local rec = ns.App.db.plans[ns.App.db.ui.pendingStart]
    local n = 0
    for _, s in ipairs(rec.plan.sections) do n = n + #s.steps end
    ns.Card.Refresh()
    T.eq(card.title.text, rec.plan.title, "heading is the plan title")
    T.eq(card.context.text, ("%d steps. Ready to test. Select Start run."):format(n), "count, status and instruction under it")
    T.eq(card.title.calls.SetMaxLines[#card.title.calls.SetMaxLines], 2, "two lines at most")
    local shown
    _G.GameTooltip = { SetOwner = function() end, SetText = function(_, t) shown = t end, Show = function() end, Hide = function() shown = nil end }
    T.ok(card.titleHit.shown, "hover area over the heading")
    card.titleHit.scripts.OnEnter(card.titleHit)
    T.eq(shown, rec.plan.title, "tooltip shows the full title")
    _G.GameTooltip = nil
    for i = #rec.plan.sections, 2, -1 do table.remove(rec.plan.sections, i) end
    rec.plan.sections[1].steps = { rec.plan.sections[1].steps[1] }
    ns.Card.Refresh()
    T.eq(card.context.text, "1 step. Ready to test. Select Start run.", "one step is singular")
    ns.App.db.currentByChar = {}; ns.App.db.plans = {}; ns.App.db.ui.pendingStart = nil; ns.App.db.ui.lastImport = nil
    ns.Card.Refresh()
    T.eq(card.title.text, "No plan yet", "no plan: heading")
    T.eq(card.context.text, "Select Import a plan and paste a plan string.", "no plan: body")
    T.ok(not card.titleHit.shown, "no hover area without a plan")
end)

test("the first visible start button sits at the left edge", function()
    local run, plan, card = startRun()
    importAgain(); ns.Card.Refresh()
    local c = card.importAgain.calls.SetPoint
    T.ok(c[1] == "LEFT" and c[2] == card.start, "with a plan: Import a plan follows Start run")
    ns.App.db.currentByChar = {}; ns.App.db.plans = {}; ns.App.db.ui.pendingStart = nil; ns.App.db.ui.lastImport = nil
    ns.Card.Refresh()
    T.ok(not card.start.shown and card.importAgain.shown, "no plan: only Import a plan")
    c = card.importAgain.calls.SetPoint
    T.ok(c[1] == "BOTTOMLEFT" and c[2] == 12 and c[3] == 12, "Import a plan takes the place of Start run")
end)

test("the ended screen offers Main window while a plan is loaded and Import a plan once it is cleared", function()
    local run, plan, card = startRun()
    ns.App.End(run.runId); ns.Card.Refresh()
    T.ok(card.exportBtn.shown and card.mainBtn.shown and not card.importAgain.shown, "plan loaded: Export results and Main window")
    local run2 = assert(ns.App.Start("KeepThat"))
    ns.Card.Refresh()
    do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
    assert(ns.App.ClearPlan(run2.runId)); ns.Card.Refresh()
    T.ok(card.exportBtn.shown, "Export results stays first")
    T.ok(card.importAgain.shown and not card.mainBtn.shown, "plan cleared: Import a plan instead of Main window")
    local c = card.importAgain.calls.SetPoint
    T.ok(c[1] == "LEFT" and c[2] == card.exportBtn, "it sits right of Export results")
    local opened
    local prompt = ns.Export.Prompt
    ns.Export.Prompt = function(title) opened = title end
    card.importAgain.scripts.OnClick()
    ns.Export.Prompt = prompt
    T.ok(opened, "it opens the import box")
end)

test("there is no Reload button: a reload request names /reload and the Run button does the work", function()
    local run, plan, card = startRun()
    T.eq(rawget(card, "reload"), nil, "no dedicated Reload button")
    plan.sections[1].steps[1].reload = "after_action"
    ns.Card.Refresh()
    T.ok(card.hint.text:find("/reload", 1, true) and not card.hint.text:find("Press Reload"), "the hint says what to type: " .. tostring(card.hint.text))
    ns.App.db.ui.shareReload = run.runId
    ns.Card.Refresh()
    T.ok(card.hint.text:find("Type /reload now", 1, true), "a share request names /reload: " .. tostring(card.hint.text))
    for _ = 1, #run.order do ns.App.Verdict("skip") end
    ns.Card.Refresh()
    T.ok(card.context.text:find("Type /reload now", 1, true), "the results screen says it too: " .. tostring(card.context.text))
    ns.App.db.ui.shareReload = nil
end)

finish()
