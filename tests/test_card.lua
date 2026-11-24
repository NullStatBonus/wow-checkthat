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

test("checks text names a fact check when the plan gives no label", function()
    local text = ns.Card.ChecksText({ { assertion = { kind = "fact" }, state = "waiting" } })
    T.ok(text:find("A fact from the addon matches", 1, true), text)
end)

-- The category tracker
local function stp(id) return { id = id, title = id, action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } } end
local function catPlan(n)
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "Cats", sections = {} }
    for i = 1, n do
        p.sections[i] = { id = "c" .. i, title = "Cat " .. i, steps = { stp("s" .. i .. "a"), stp("s" .. i .. "b") } }
    end
    return p
end
local function startCats(n, picks)
    ns.addon.db.profile.card.collapsed = false
    ns.addon.db.profile.card.textOpacity = 100
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(catPlan(n)))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local run = assert(ns.App.Start("KeepThat", picks))
    ns.Card.Show()
    return run, _G.CheckThatCard
end
local function color(tex) local c = tex.calls.SetColorTexture; return { c[1], c[2], c[3] } end
local function shownParts(seg) local n = 0; for _, t in ipairs(seg.parts) do if t.shown then n = n + 1 end end; return n end
local function verdict(run, id, v)
    local _, ctx = ns.App.Current()
    ns.Run.Begin(run, ctx, id); ns.Run.Verdict(run, ctx, id, v); ns.Card.Refresh()
end

test("the tracker layout: none for one category, segments for two to eight, one bar beyond", function()
    local function rows(n, picked)
        local out = {}
        for i = 1, n do out[i] = { id = "c" .. i, title = "C" .. i, state = "grey", picked = picked ~= false and true,
            counts = { resolved = 0, total = 2, open = 2, pass = 0, fail = 0 } } end
        return out
    end
    T.eq(ns.Card.Tracker(rows(1), "grey", { total = 2, resolved = 0 }, 356), nil)
    local two = ns.Card.Tracker(rows(2), "grey", { total = 4, resolved = 0 }, 356)
    T.eq(two.mode, "segments"); T.eq(#two.segs, 2); T.eq(two.segs[1].w, 177); T.eq(two.segs[2].x, 179)
    local eight = ns.Card.Tracker(rows(8), "grey", { total = 16, resolved = 0 }, 356)
    T.eq(#eight.segs, 8)
    local last = eight.segs[8]
    T.ok(last.x + last.w <= 356, "the last segment stays inside the card")
    local nine = ns.Card.Tracker(rows(9), "red", { total = 18, resolved = 9 }, 356)
    T.eq(nine.mode, "bar"); T.eq(nine.state, "red")
    local nr = rows(9); for _, x in ipairs(nr) do x.counts.pass = 1; x.counts.fail = 1 end
    local split = ns.Card.Tracker(nr, "red", { total = 18, pass = 9, fail = 9, resolved = 18, open = 0 }, 356)
    T.eq(#split.parts, 2); T.eq(split.parts[1].state, "green"); T.eq(split.parts[1].w, 178); T.eq(split.parts[2].state, "red"); T.eq(split.parts[2].x, 178)
    local r = rows(3); r[2].picked = false; r[2].state = "off"; r[2].counts = { resolved = 0, total = 0, open = 0, pass = 0, fail = 0 }
    local segs = ns.Card.Tracker(r, "grey", { total = 4, resolved = 0 }, 356).segs
    T.eq(#segs, 3, "an unpicked category keeps its place"); T.eq(#segs[2].parts, 0)
end)

test("the caption names the overall result in words", function()
    T.eq(ns.Card.Caption("red", { fail = 1, pass = 3, resolved = 4, total = 8 }), "1 failed · 3 of 8 passed")
    T.eq(ns.Card.Caption("red", { fail = 3, pass = 1, resolved = 4, total = 8 }), "3 failed · 1 of 8 passed")
    T.eq(ns.Card.Caption("blue", { pass = 1, resolved = 1, total = 8 }), "in progress · 1 of 8 passed")
    T.eq(ns.Card.Caption("yellow", { partial = 1, pass = 1, resolved = 2, total = 8 }), "1 partial · 1 of 8 passed")
    T.eq(ns.Card.Caption("yellow", { unverified = 2, pass = 0, resolved = 0, total = 8 }), "2 unverified · 0 of 8 passed")
    T.eq(ns.Card.Caption("yellow", { partial = 1, unverified = 2, pass = 4, resolved = 5, total = 8 }), "1 partial, 2 unverified · 4 of 8 passed")
    T.eq(ns.Card.Caption("green", { pass = 8, resolved = 8, total = 8 }), "passed · 8 of 8 passed")
    T.eq(ns.Card.Caption("blue", { pass = 0, resolved = 0, total = 8 }), "untested · 0 of 8 passed")
    T.eq(ns.Card.Caption("grey", { pass = 0, resolved = 3, total = 3 }), "all skipped · 0 of 3 passed")
end)

test("the card shows one segment per category, colored by state, with the caption", function()
    local run, card = startCats(3)
    local shown = 0
    for _, s in ipairs(card.segs) do if s.back.shown then shown = shown + 1 end end
    T.eq(shown, 3); T.ok(card.segs[1].back.shown and card.segs[3].back.shown)
    T.eq(card.barBack.shown, false, "the plain bar gives way to the segments")
    T.eq(card.caption.text, "untested · 0 of 6 passed"); T.ok(card.catBtn.shown)
    T.eq(shownParts(card.segs[1]), 0, "nothing colored at zero progress")
    verdict(run, "s1a", "pass")
    T.eq(shownParts(card.segs[1]), 1); T.eq(color(card.segs[1].parts[1])[2], 0.8, "the passed half is green")
    T.eq(card.segs[1].parts[1].calls.SetSize[1], 59, "half of the 117 unit segment")
    verdict(run, "s1b", "pass")
    T.eq(card.segs[1].parts[1].calls.SetSize[1], 117, "all passed: the whole segment")
    verdict(run, "s2a", "fail"); verdict(run, "s2b", "pass")
    T.eq(shownParts(card.segs[2]), 2, "one failed and one passed: two colors in one segment")
    T.eq(color(card.segs[2].parts[1])[2], 0.8, "green first"); T.eq(color(card.segs[2].parts[2])[1], 0.9, "red last")
    T.eq(card.caption.text, "1 failed · 3 of 6 passed")
    T.eq(card.segs[2].hit.tip, "Cat 2 (c2): failed, 1 passed, 1 failed, 0 open", "the tooltip says it in words")
end)

test("yellow shows a partial step, and blue stays for steps not yet tested", function()
    local run, card = startCats(3)
    verdict(run, "s1a", "partial")
    T.eq(color(card.segs[1].parts[1])[1], 1); T.eq(color(card.segs[1].parts[1])[2], 0.82, "yellow: a partial result")
    T.eq(card.caption.text, "1 partial · 0 of 6 passed")
    verdict(run, "s2a", "pass")
    T.eq(color(card.segs[2].parts[1])[2], 0.8, "green for the passed step"); T.eq(card.segs[2].back.calls.SetColorTexture[3], 0.3, "the track behind stays dim blue: a step is untested")
    verdict(run, "s3a", "skip"); verdict(run, "s3b", "skip")
    T.eq(shownParts(card.segs[3]), 0, "only skips: nothing colored")
end)

test("the content moves down by the caption row only when the tracker shows", function()
    local run, card = startCats(3)
    local with = card.title.calls.SetPoint
    local run2, card2 = startCats(1)
    local without = card2.title.calls.SetPoint
    T.eq(with[5] - without[5], -12, "the title sits 12 lower (SetPoint takes the negative y)")
end)

test("one category keeps the plain bar and no caption", function()
    local run, card = startCats(1)
    T.eq(card.barBack.shown, true); T.eq(card.caption.shown, false); T.eq(card.catBtn.shown, false)
    for _, s in ipairs(card.segs) do T.eq(s.back.shown, false) end
end)

test("more than eight categories show one bar colored by the overall state", function()
    local run, card = startCats(9)
    T.eq(card.barBack.shown, true)
    for _, s in ipairs(card.segs) do T.eq(s.back.shown, false) end
    verdict(run, "s1a", "fail"); verdict(run, "s2a", "pass")
    T.eq(color(card.barParts[1])[2], 0.8, "green for the passed step"); T.eq(color(card.barParts[2])[1], 0.9, "red for the failed one")
    T.ok(card.caption.text:find("1 failed", 1, true))
end)

test("nothing of the tracker is drawn at zero text opacity", function()
    local run, card = startCats(3)
    ns.addon.db.profile.card.textOpacity = 0
    ns.Card.Refresh()
    T.eq(card.segs[1].back.shown, false); T.eq(shownParts(card.segs[1]), 0)
    ns.addon.db.profile.card.textOpacity = 100
end)

test("the collapsed card keeps the caption and the title moves down with it", function()
    local run, card = startCats(3)
    collapse(true)
    T.eq(card.caption.shown, true); T.eq(card.catBtn.shown, false, "the Categories list is in the full card")
    collapse(false)
end)

local function captureMenu()
    local got = {}
    _G.MenuUtil = { CreateContextMenu = function(owner, gen)
        local root = { CreateButton = function(_, label, fn) got[#got + 1] = { label, fn } end }
        gen(owner, root)
    end }
    return got
end
test("the Categories control opens the Categories window and closes it again", function()
    local run, card = startCats(3)
    card.catBtn.scripts.OnClick(card.catBtn)
    T.eq(_G.CheckThatCategories:IsShown(), true)
    card.catBtn.scripts.OnClick(card.catBtn)
    T.eq(_G.CheckThatCategories:IsShown(), false)
end)

test("the checks list carries an amber warning only when asked", function()
    local items = { { assertion = { kind = "log" }, state = "waiting" } }
    T.ok(not ns.Card.ChecksText(items, false, nil, false):find("cannot see Lua errors", 1, true))
    T.ok(ns.Card.ChecksText(items, false, nil, true):find("|cffffaa00CheckThat cannot detect new Lua errors.", 1, true))
end)

test("a step that reads the Lua error list shows the warning while nothing records errors", function()
    local p = catPlan(1)
    p.logs = { errors = { global = "CheckThatDB", path = "global.errors", format = "strings", quiet = true, cap = 100 } }
    p.sections[1].steps[1] = { id = "s1a", title = "No Lua error", action = { kind = "manual", text = "t" }, expect = "e",
        verify = { "assertions" }, assertions = { { kind = "log", source = "errors", pattern = ".", absent = true } } }
    ns.addon.db.profile.card.collapsed = false
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.Start("KeepThat")); ns.Card.Show()
    local covered = ns.Errors.Covered
    ns.Errors.Covered = function() return false end -- no handler of ours and no BugGrabber
    ns.Card.Refresh()
    local card = _G.CheckThatCard
    T.eq(ns.Errors.Blind(), true)
    T.ok(card.checks.text:find("cannot detect new Lua errors", 1, true), tostring(card.checks.text))
    ns.Errors.Covered = function() return true end
    ns.Card.Refresh(); ns.Card.UpdateChecks()
    T.ok(not card.checks.text:find("cannot detect new Lua errors", 1, true), "covered again: the warning goes")
    ns.Errors.Covered = function() return false end
    ns.Card.UpdateChecks()
    T.ok(card.checks.text:find("cannot detect new Lua errors", 1, true), "the live update lays the card out again and shows the warning")
    ns.Errors.Covered = covered
end)

test("rerun asks first and reopens only when the player accepts", function()
    local run, card = startCats(2)
    verdict(run, "s1a", "pass")
    local dialog
    _G.StaticPopup_Show = function() end
    ns.Card.ConfirmRerun("c1", 1, "Cat 1")
    dialog = _G.StaticPopupDialogs.WOWCHECKTHAT_CONFIRM
    T.ok(dialog.text:find("Rerun Cat 1? This reopens 1 completed step. Earlier", 1, true), dialog.text)
    T.eq(run.steps.s1a.verdict, "pass", "asking changes nothing")
    local said = {}
    local print0 = ns.Slash.Print; ns.Slash.Print = function(m) said[#said + 1] = m end
    dialog.OnAccept()
    T.eq(run.steps.s1a.verdict, "pending"); T.eq(said[1], "Reopened 1 step in Cat 1.")
    verdict(run, "s1a", "pass"); verdict(run, "s1b", "pass")
    ns.Card.ConfirmRerun("c1", 2, "Cat 1")
    T.ok(_G.StaticPopupDialogs.WOWCHECKTHAT_CONFIRM.text:find("reopens 2 completed steps", 1, true))
    _G.StaticPopupDialogs.WOWCHECKTHAT_CONFIRM.OnAccept()
    T.eq(said[2], "Reopened 2 steps in Cat 1."); ns.Slash.Print = print0
end)
test("rerun failed asks about the failed steps and says nothing when none failed", function()
    local run = startCats(2)
    local said = {}
    local print0 = ns.Slash.Print; ns.Slash.Print = function(m) said[#said + 1] = m end
    _G.StaticPopup_Show = function() end
    ns.Card.AskRerun("failed"); T.eq(said[1], "No step has failed or is unverified.")
    verdict(run, "s1a", "fail")
    ns.Card.AskRerun("failed")
    local dialog = _G.StaticPopupDialogs.WOWCHECKTHAT_CONFIRM
    T.ok(dialog.text:find("Rerun the 1 failed or unverified step? Earlier", 1, true), dialog.text)
    dialog.OnAccept(); T.eq(run.steps.s1a.verdict, "pending"); T.eq(said[2], "Reopened 1 failed or unverified step.")
    ns.Slash.Print = print0
end)

test("the start screen lists categories as checkboxes, all checked, and starts with the checked ones", function()
    ns.addon.db.profile.card.collapsed = false
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(catPlan(3)))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil; ns.App.db.ui.cleared = nil
    ns.Card.Show(); ns.Card.Refresh()
    local card = _G.CheckThatCard
    T.ok(card.picks[1].check.shown and card.picks[3].check.shown); T.eq(card.picks[1].label.text, "Cat 1: 2 steps")
    -- clearing the second checkbox
    card.picks[2].check.GetChecked = function() return false end
    card.picks[2].check.scripts.OnClick(card.picks[2].check)
    T.eq(ns.App.db.ui.cleared.KeepThat.c2, true)
    card.start.scripts.OnClick(card.start)
    local run = ns.App.Current()
    T.eq(run.selected.c1, true); T.eq(run.selected.c2, nil); T.eq(run.steps.s2a.verdict, "deselected")
end)

test("with every category cleared, Start run is off and the card says why", function()
    ns.addon.db.profile.card.collapsed = false
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(catPlan(2)))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    ns.App.db.ui.cleared = { KeepThat = { c1 = true, c2 = true } }
    ns.Card.Show(); ns.Card.Refresh()
    local card = _G.CheckThatCard
    T.eq(card.start.calls.SetEnabled[1], false); T.eq(card.pickNote.text, "Select at least one category.")
    ns.App.db.ui.cleared = nil
end)

test("a rerun question belongs to the run it was asked in", function()
    local run, card = startCats(2)
    verdict(run, "s1a", "pass")
    _G.StaticPopup_Show = function() end
    ns.Card.ConfirmRerun("c1", 1, "Cat 1")
    local dialog = _G.StaticPopupDialogs.WOWCHECKTHAT_CONFIRM
    local other = startCats(2)                      -- another run takes the card
    dialog.OnAccept()
    T.eq(run.steps.s1a.verdict, "pass", "nothing was reopened in the first run")
    T.eq(other.steps.s1a.verdict, "pending", "or in the second")
end)

test("the opacity setting reaches the overall bar and hides the tracker at zero at once", function()
    local run, card = startCats(9)
    T.eq(card.barBack.shown, true)
    ns.addon.db.profile.card.textOpacity = 0
    ns.Card.ApplyAppearance()
    T.eq(card.barBack.shown, false, "no redraw call from the test: the setting path alone hides it")
    ns.addon.db.profile.card.textOpacity = 50
    ns.Card.ApplyAppearance()
    T.eq(card.barBack.shown, true); T.eq(card.barBack.calls.SetAlpha[1], 0.5)
    ns.addon.db.profile.card.textOpacity = 100
    ns.Card.ApplyAppearance()
end)

test("with more than eight categories the card offers the picker, which pages and shares the picked set", function()
    ns.addon.db.profile.card.collapsed = false
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(catPlan(30)))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil; ns.App.db.ui.cleared = nil
    ns.Card.Show(); ns.Card.Refresh()
    local card = _G.CheckThatCard
    T.eq(card.chooseBtn.shown, true); T.eq(card.pickNote.text, "30 of 30 categories picked.")
    card.chooseBtn.scripts.OnClick(card.chooseBtn)
    local pk = _G.CheckThatPicker
    pk.down.scripts.OnClick(pk.down); pk.down.scripts.OnClick(pk.down)
    T.eq(pk.rows[1].label.text, "Cat 29: 2 steps", "a short last page keeps 14-row steps")
    pk.up.scripts.OnClick(pk.up)
    T.eq(pk.rows[1].label.text, "Cat 15: 2 steps")
    pk:Hide()
    T.ok(not card.picks[9] or not card.picks[9].check.shown, "no inline boxes above eight")
    card.chooseBtn.scripts.OnClick(card.chooseBtn)
    local win = _G.CheckThatPicker
    T.eq(win:IsShown(), true); T.eq(win.rows[14].check.shown, true); T.eq(win.rows[15], nil)
    T.eq(win.more.text, "Showing 1 to 14 of 30. Use the mouse wheel to see more.")
    win.down.scripts.OnClick(win.down)
    T.eq(win.rows[1].label.text, "Cat 15: 2 steps")
    win.rows[1].check.GetChecked = function() return false end
    win.rows[1].check.scripts.OnClick(win.rows[1].check)
    T.eq(ns.App.db.ui.cleared.KeepThat.c15, true); T.eq(card.pickNote.text, "29 of 30 categories picked.")
    for i = 1, 30 do ns.App.SetPick("KeepThat", "c" .. i, false) end
    ns.Card.Refresh()
    T.eq(card.start.calls.SetEnabled[#card.start.calls.SetEnabled], false); T.eq(win.none.text, "Select at least one category.")
    ns.App.db.ui.cleared = nil
    ns.Card.Refresh()
    card.start.scripts.OnClick(card.start)
    T.eq(win:IsShown(), false, "Start run closes the picker")
end)

test("a bound key records the same result as the button, only with a step on the card", function()
    local run, card = startCats(2)
    _G.SlashCmdList["ACECONSOLE_CT"]("debug on")
    ns.Card.Refresh()
    T.eq(_G.BINDING_NAME_CHECKTHAT_FAIL, "Fail"); T.eq(type(_G.CheckThat_Key), "function")
    CheckThat_Key("pass")
    T.eq(run.steps.s1a.verdict, "pass"); T.eq(ns.Run.CurrentId(run), "s1b", "the card moves on, as for the button")
    card:Hide()
    CheckThat_Key("fail")
    T.eq(run.steps.s1b.verdict, "pending", "a hidden card records nothing")
    local lines = {}
    for _, e in ipairs(ns.Log.Entries()) do lines[#lines + 1] = e.msg end
    local joined = table.concat(lines, "\n")
    T.ok(joined:find("key pass", 1, true) and joined:find("key fail ignored: card not visible", 1, true), joined)
    card:Show(); ns.Card.Refresh()
    card.IsVisible = function() return false end -- the interface is hidden (Alt+Z): the card keeps its shown flag
    CheckThat_Key("fail")
    T.eq(run.steps.s1b.verdict, "pending", "hidden interface records nothing")
    card.IsVisible = nil
    CheckThat_Key("skip"); T.eq(run.steps.s1b.verdict, "skip")
    run.endedAt = 1; ns.Card.Refresh()
    CheckThat_Key("pass")
    T.eq(run.steps.s2a.verdict, "pending", "an ended run takes no key")
    run.endedAt = nil
    _G.SlashCmdList["ACECONSOLE_CT"]("debug off")
end)

test("with more than eight categories all cleared, the card start screen turns Start run off", function()
    ns.addon.db.profile.card.collapsed = false
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(catPlan(9)))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local off = {}
    for i = 1, 9 do off["c" .. i] = true end
    ns.App.db.ui.cleared = { KeepThat = off }
    ns.Card.Show(); ns.Card.Refresh()
    local card = _G.CheckThatCard
    T.eq(card.start.calls.SetEnabled[1], false); T.eq(card.pickNote.text, "Select at least one category.")
    ns.App.db.ui.cleared = nil
end)

finish()
