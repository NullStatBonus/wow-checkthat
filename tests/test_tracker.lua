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

test("without a menu a click runs the main item", function()
    local run = start(3, { "c1", "c2" })
    ns.Tracker.Show()
    _G.MenuUtil, _G.UIDropDownMenu_Initialize = nil, nil
    T.eq(ns.Run.CurrentId(run), "s1a")
    win().rows[2].scripts.OnClick(win().rows[2])
    T.eq(ns.Run.CurrentId(run), "s2a", "the main item ran: go to the first open step of Cat 2")
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
