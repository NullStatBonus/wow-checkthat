local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- The Categories window, driven through the real addon against the stub client.
local st = H.stubClient()
H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
CheckThatDB = nil
ns.addon:OnInitialize(); ns.addon:OnEnable()
local function stp(id) return { id = id, title = id, action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } } end
local function plan(n)
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "Many", sections = {} }
    for i = 1, n do p.sections[i] = { id = "c" .. i, title = "Cat " .. i, steps = { stp("s" .. i .. "a"), stp("s" .. i .. "b") } } end
    return p
end
local function start(n, picks)
    ns.addon.db.profile.card.collapsed = false
    ns.addon.db.profile.card.textOpacity = 100
    ns.addon.db.profile.card.backgroundOpacity = 90
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(plan(n)))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local run = assert(ns.App.Start("KeepThat", picks))
    ns.Card.Show()
    return run
end
local function verdict(run, id, v)
    local _, ctx = ns.App.Current()
    ns.Run.Begin(run, ctx, id); ns.Run.Verdict(run, ctx, id, v); ns.Card.Refresh()
end
local function win() return _G.CheckThatCategories end
local function color(tex) local c = tex.calls.SetColorTexture; return { c[1], c[2], c[3] } end
local function shownRows() local n = 0; for _, r in ipairs(win().rows) do if r.shown then n = n + 1 end end; return n end

test("the window is hidden until the player opens it, and /ct tracker toggles it", function()
    start(3)
    T.ok(win() == nil or not win():IsShown())
    local slash = assert(_G.SlashCmdList["ACECONSOLE_CT"])
    slash("tracker"); T.eq(win():IsShown(), true)
    slash("tracker"); T.eq(win():IsShown(), false)
    slash("tracker now"); T.eq(win():IsShown(), false, "surplus input is refused")
end)

test("it lists every category, also with a dozen and more, with color and words", function()
    local run = start(12)
    ns.Tracker.Show()
    T.eq(shownRows(), 12)
    T.eq(win().rows[1].label.text, "Cat 1")
    T.eq(win().rows[1].detail.text, "untested · 0 passed, 0 failed, 2 open")
    T.eq(color(win().rows[1].swatch)[1], 0.4, "blue: untested")
    verdict(run, "s1a", "pass"); verdict(run, "s2a", "fail"); verdict(run, "s3a", "pass"); verdict(run, "s3b", "pass")
    T.eq(win().rows[1].detail.text, "in progress · 1 passed, 0 failed, 1 open")
    T.eq(win().rows[2].detail.text, "failed · 0 passed, 1 failed, 1 open"); T.eq(color(win().rows[2].swatch)[1], 0.9)
    T.eq(win().rows[3].detail.text, "passed · 2 passed, 0 failed, 0 open"); T.eq(color(win().rows[3].swatch)[1], 0.1)
    T.eq(win().caption.shown, false, "no overall count in the header: each row has its own")
end)

test("a list longer than the window scrolls with the mouse wheel and says what shows", function()
    local run = start(20)
    ns.Tracker.Show()
    T.eq(shownRows(), 14)
    T.eq(win().more.text, "Showing 1 to 14 of 20. Use the mouse wheel to see more.")
    win().scripts.OnMouseWheel(win(), -1); win().scripts.OnMouseWheel(win(), -1)
    T.eq(win().rows[1].label.text, "Cat 3"); T.eq(win().more.text, "Showing 3 to 16 of 20. Use the mouse wheel to see more.")
    for _ = 1, 30 do win().scripts.OnMouseWheel(win(), -1) end
    T.eq(win().rows[14].label.text, "Cat 20", "it stops at the end")
    for _ = 1, 30 do win().scripts.OnMouseWheel(win(), 1) end
    T.eq(win().rows[1].label.text, "Cat 1", "and at the start")
end)

test("page buttons move the list a page at a time and stop at the ends", function()
    local run = start(40)
    ns.Tracker.Show()
    T.eq(win().up.enabled == false or win().up.calls.SetEnabled[1] == false, true, "no page before the first")
    win().down.scripts.OnClick(win().down)
    T.eq(win().rows[1].label.text, "Cat 15")
    win().down.scripts.OnClick(win().down); win().down.scripts.OnClick(win().down)
    T.eq(win().rows[14].label.text, "Cat 40"); T.eq(win().more.text, "Showing 27 to 40 of 40. Use the mouse wheel to see more.")
    T.eq(win().down.calls.SetEnabled[1], false, "no page after the last")
    win().up.scripts.OnClick(win().up)
    T.eq(win().rows[1].label.text, "Cat 13", "a page back from the end: the last page was a short step")
end)

test("a row says it takes a click, and Esc closes the window without a reload bringing it back", function()
    start(3)
    ns.Tracker.Show()
    T.ok(win().rows[1].tip:find("Click for actions.", 1, true), win().rows[1].tip)
    local registered = false
    for _, name in ipairs(_G.UISpecialFrames or {}) do if name == "CheckThatCategories" then registered = true end end
    T.eq(registered, true, "Esc is wired through UISpecialFrames")
    win():Hide()
    T.eq(ns.addon.db.profile.card.trackerOpen, false, "hidden by Esc: it stays closed")
    ns.Tracker.Show()
    ns.Tracker.Leaving()
    win():Hide()
    T.eq(ns.addon.db.profile.card.trackerOpen, true, "hidden by a logout or reload: it comes back")
end)

test("a new run starts at the top of the list", function()
    start(40)
    ns.Tracker.Show()
    win().down.scripts.OnClick(win().down)
    T.eq(win().rows[1].label.text, "Cat 15")
    start(40)
    T.eq(win().rows[1].label.text, "Cat 1")
end)

test("a category that was not picked shows as not picked", function()
    local run = start(3, { "c1" })
    ns.Tracker.Show()
    T.eq(win().rows[2].detail.text, "not picked")
end)

test("a click on a row offers add, go to the first open step, and rerun for that category only", function()
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    verdict(run, "s1a", "pass")
    local got = {}
    _G.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, { CreateButton = function(_, label, fn) got[#got + 1] = { label, fn } end }) end }
    win().rows[1].scripts.OnClick(win().rows[1])
    local labels = {}; for _, it in ipairs(got) do labels[#labels + 1] = it[1] end
    T.eq(table.concat(labels, "|"), "Go to first open step: Cat 1|Rerun category: Cat 1")
    got = {}
    win().rows[3].scripts.OnClick(win().rows[3])
    T.eq(#got, 1); T.eq(got[1][1], "Add to run: Cat 3")
    got[1][2]()
    T.eq(run.selected.c3, true); T.eq(ns.Run.CurrentId(run), "s1b", "adding leaves the shown step")
    T.eq(win().rows[3].detail.text, "untested · 0 passed, 0 failed, 2 open", "the window follows the change")
    _G.MenuUtil = nil
end)

test("a clean category offers Remove from run and a category with a result does not", function()
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    verdict(run, "s1a", "pass")
    local got = {}
    _G.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, { CreateButton = function(_, label, fn) got[#got + 1] = { label, fn } end }) end }
    win().rows[2].scripts.OnClick(win().rows[2])
    local labels = {}; for _, it in ipairs(got) do labels[#labels + 1] = it[1] end
    T.eq(table.concat(labels, "|"), "Go to first open step: Cat 2|Remove from run: Cat 2")
    got[2][2]()
    T.eq(run.selected.c2, nil); T.eq(win().rows[2].detail.text, "not picked", "the window follows the change")
    _G.MenuUtil = nil
end)

test("a failed step adds a row that reruns every failed and unverified step", function()
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    verdict(run, "s1a", "pass"); verdict(run, "s2a", "fail")
    local got = {}
    _G.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, { CreateButton = function(_, label, fn) got[#got + 1] = { label, fn } end }) end }
    win().rows[1].scripts.OnClick(win().rows[1])
    T.eq(got[#got][1], "Rerun failed and unverified steps in all categories")
    got = {}
    win().rows[3].scripts.OnClick(win().rows[3]) -- not picked: its own item and the failed row
    T.eq(#got, 2); T.eq(got[2][1], "Rerun failed and unverified steps in all categories")
    _G.MenuUtil = nil
end)

test("without a menu a click shows every item and runs none until one is picked", function()
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    _G.MenuUtil, _G.UIDropDownMenu_Initialize = nil, nil
    verdict(run, "s1a", "pass") -- Cat 1 now has a result and an open step: go, rerun and remove are not all offered
    ns.Run.Select(run, select(2, ns.App.Current()), "c1")
    T.eq(ns.Run.CurrentId(run), "s1b")
    local list = _G.CheckThatCategoryList
    T.eq(list, nil, "no list before a click")
    win().rows[2].scripts.OnClick(win().rows[2])
    list = _G.CheckThatCategoryList
    T.eq(list:IsShown(), true)
    local shown = {}
    for _, b in ipairs(list.buttons) do if b.shown then shown[#shown + 1] = b end end
    T.ok(#shown >= 1, "an item for the row")
    T.eq(ns.Run.CurrentId(run), "s1b", "nothing ran yet")
    local first = shown[1]
    first.scripts.OnClick(first)
    T.eq(ns.Run.CurrentId(run), "s2a", "the picked item ran: go to the first open step of Cat 2")
    T.eq(list:IsShown(), false, "a pick closes the list")
end)

test("the item list holds every item of a row with results, and Esc closes only the list", function()
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    _G.MenuUtil, _G.UIDropDownMenu_Initialize = nil, nil
    verdict(run, "s1a", "pass"); verdict(run, "s1b", "pass")
    win().rows[1].scripts.OnClick(win().rows[1])
    local list = _G.CheckThatCategoryList
    local labels = {}
    for _, b in ipairs(list.buttons) do if b.shown then labels[#labels + 1] = b.text end end
    T.eq(labels[1], "Rerun category: Cat 1", "rerun is reachable")
    T.eq(#labels, 1, "a category with results cannot be removed")
    win().rows[2].scripts.OnClick(win().rows[2])
    labels = {}
    for _, b in ipairs(list.buttons) do if b.shown then labels[#labels + 1] = b.text end end
    T.eq(labels[1], "Go to first open step: Cat 2"); T.eq(labels[2], "Remove from run: Cat 2"); T.eq(#labels, 2)
    list.scripts.OnKeyDown(list, "A")
    T.eq(list.calls.SetPropagateKeyboardInput[1], true, "other keys pass on"); T.eq(list:IsShown(), true)
    list.scripts.OnKeyDown(list, "ESCAPE")
    T.eq(list.calls.SetPropagateKeyboardInput[1], false, "Esc is taken here, not by the window behind")
    T.eq(list:IsShown(), false); T.eq(win():IsShown(), true)
    win().rows[1].scripts.OnClick(win().rows[1]); T.eq(list:IsShown(), true)
    ns.Tracker.Hide(); T.eq(list:IsShown(), false, "hiding the window closes the list")
end)

local function logged(text)
    for _, e in ipairs(ns.Log.Entries()) do if tostring(type(e) == "table" and e.msg or e):find(text, 1, true) then return true end end
    return false
end
local function toggle(i) local r = win().rows[i]; r.toggle.scripts.OnClick(r.toggle) end

test("a row expands to its steps with result words and marks, and collapses again", function()
    _G.SlashCmdList["ACECONSOLE_CT"]("debug on")
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    T.eq(shownRows(), 3, "collapsed by default")
    verdict(run, "s1a", "pass"); verdict(run, "s1b", "fail")
    toggle(1)
    T.eq(shownRows(), 5)
    T.eq(win().rows[2].label.text, "s1a"); T.eq(win().rows[2].detail.text:find("passed", 1, true) ~= nil, true)
    T.ok(win().rows[2].detail.text:find("ReadyCheck-Ready", 1, true), "a mark besides the word")
    T.eq(win().rows[3].label.text, "s1b"); T.ok(win().rows[3].detail.text:find("failed", 1, true) and win().rows[3].detail.text:find("NotReady", 1, true))
    T.eq(win().rows[4].label.text, "Cat 2", "the next category follows the steps")
    T.ok(logged("tracker expand c1"), "the toggle is logged")
    toggle(1)
    T.eq(shownRows(), 3); T.ok(logged("tracker collapse c1"))
end)

test("the steps of a category that is not picked read not picked, and a click on one does nothing", function()
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    toggle(3)
    T.eq(win().rows[4].detail.text, "not picked")
    local before = ns.Run.CurrentId(run)
    local printed, print0 = 0, ns.Slash.Print
    ns.Slash.Print = function() printed = printed + 1 end
    win().rows[4].scripts.OnClick(win().rows[4])
    ns.Slash.Print = print0
    T.eq(printed, 0, "it does nothing, not even a chat line")
    T.eq(ns.Run.CurrentId(run), before); T.eq(run.selected.c3, nil, "the category stays unpicked")
    T.eq(run.steps.s3a.verdict, "deselected")
end)

test("a step that is not for this client is listed as such and a click on it does nothing", function()
    local p = plan(2); p.sections[1].steps[2].clients = { "forever-camelot" }   -- the stub client is Era
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local run = assert(ns.App.Start("KeepThat", { "c1", "c2" }))
    ns.Card.Show(); ns.Tracker.Show(); toggle(1)
    T.eq(win().rows[2].detail.text, "open"); T.eq(win().rows[3].detail.text, "not for this client")
    local printed, print0 = 0, ns.Slash.Print
    ns.Slash.Print = function() printed = printed + 1 end
    local before = ns.Run.CurrentId(run)
    win().rows[3].scripts.OnClick(win().rows[3])
    ns.Slash.Print = print0
    T.eq(printed, 0); T.eq(ns.Run.CurrentId(run), before); T.eq(run.steps.s1b.verdict, "inapplicable")
end)

test("a click on a step row shows that step and changes no result", function()
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    verdict(run, "s1a", "pass")
    toggle(2)
    local counts = ns.Run.Counts(run)
    local want
    for i = 1, 5 do if win().rows[i].shown and win().rows[i].label.text == "s2b" then want = win().rows[i] end end
    want.scripts.OnClick(want)
    T.eq(ns.Run.CurrentId(run), "s2b", "the card shows the step")
    local after = ns.Run.Counts(run)
    for k, v in pairs(counts) do T.eq(after[k], v, k) end
    T.eq(run.steps.s1a.verdict, "pass")
end)

test("a step named like a category opens as a step", function()
    local p = plan(2); p.sections[2].steps[1].id = "c1"   -- the step c1 sits in category c2
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    local run = assert(ns.App.Start("KeepThat", { "c1", "c2" }))
    ns.Card.Show(); ns.Tracker.Show()
    toggle(2)
    local row
    for i = 1, 5 do if win().rows[i].shown and win().rows[i].label.text == "s2a" then row = win().rows[i] end end   -- the title; its id is c1
    row.scripts.OnClick(row)
    T.eq(ns.Run.CurrentId(run), "c1", "the step, not the category")
end)

test("expanding steps counts in the paging and keeps the row limit", function()
    local run = start(10)
    ns.Tracker.Show()
    for i = 1, 3 do toggle(1 + (i - 1) * 3) end   -- three categories open: 10 + 6 rows
    T.eq(shownRows(), 14)
    T.eq(win().more.text, "Showing 1 to 14 of 16. Use the mouse wheel to see more.")
end)

test("the expanded rows are forgotten when another run is shown", function()
    local run = start(3)
    ns.Tracker.Show(); toggle(1); T.eq(shownRows(), 5)
    start(3); ns.Tracker.Refresh()
    T.eq(shownRows(), 3)
end)

test("a reused row frame changes kind without keeping the old click, tooltip or button", function()
    local run = start(3)
    ns.Tracker.Show()
    local row = win().rows[2]
    T.ok(row.toggle.shown ~= false and row.arrow.shown ~= false, "a category row has the button and the arrow")
    toggle(1)   -- row 2 is now a step
    T.eq(row.stepData and row.stepData.id, "s1a"); T.eq(row.toggle.shown, false)
    T.ok(row.tip:find("Click to show this step.", 1, true))
    toggle(1)
    T.eq(row.stepData, false); T.ok(row.tip:find("Click for actions.", 1, true))
end)

test("nothing of the expanded rows is drawn at zero opacity", function()
    local run = start(3)
    ns.addon.db.profile.card.textOpacity = 0
    ns.Tracker.Show(); toggle(1)
    T.eq(win().rows[2].detail.calls.SetAlpha[1], 0); T.eq(win().rows[1].toggle.calls.SetAlpha[1], 0)
    ns.addon.db.profile.card.textOpacity = 100
end)

test("with no run the window says so", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    ns.Tracker.Show()
    T.eq(win().caption.text, "There is no run.")
    T.eq(shownRows(), 0)
end)

test("the position is saved and the window comes back after a reload if it was open", function()
    start(3)
    ns.Tracker.Show()
    win():GetPoint()
    win().scripts.OnDragStop(win())
    T.ok(ns.addon.db.profile.card.trackerPos, "the position is kept")
    T.eq(ns.addon.db.profile.card.trackerOpen, true)
    ns.Tracker.Hide()
    T.eq(ns.addon.db.profile.card.trackerOpen, false)
end)

test("nothing is drawn at zero background opacity, and the text follows the text opacity", function()
    start(3)
    ns.Tracker.Show()
    ns.addon.db.profile.card.backgroundOpacity = 0
    ns.Tracker.ApplyAppearance()
    T.eq(win().calls.SetBackdrop[1], nil, "no backdrop at zero")
    ns.addon.db.profile.card.textOpacity = 40
    ns.Tracker.ApplyAppearance()
    T.eq(win().caption.calls.SetAlpha[1], 0.4); T.eq(win().rows[1].label.calls.SetAlpha[1], 0.4)
    ns.addon.db.profile.card.backgroundOpacity = 90; ns.addon.db.profile.card.textOpacity = 100
end)

finish()
