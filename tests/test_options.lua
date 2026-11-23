local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- Loads the real Ace libraries and checks the settings pages against AceConfig's own validator.
local st = H.stubClient()
H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
CheckThatDB = nil
ns.addon:OnInitialize()

test("the tree validates and has the shared pages in order", function()
    local tree = ns.Options.Build()
    local reg = LibStub("AceConfigRegistry-3.0")
    T.ok(pcall(reg.ValidateOptionsTable, reg, tree, "CheckThat"))
    local order = {}
    for key, g in pairs(tree.args) do order[g.order] = key end
    T.eq(table.concat(order, ","), "home,plans,appearance,advanced,about")
    T.eq(tree.childGroups, "tree")
end)
test("sliders and toggles write through the shared validators", function()
    local g = ns.Options.Appearance(3)
    local s = g.args["card.scale"]
    T.eq(s.min, 50); T.eq(s.max, 200); T.eq(s.width, 1.5)
    s.set(nil, 130); T.eq(ns.addon.db.profile.card.scale, 130)
    s.set(nil, 999); T.eq(ns.addon.db.profile.card.scale, 130, "out of range ignored")
    g.args["card.locked"].set(nil, true); T.eq(ns.addon.db.profile.card.locked, true)
    g.args["reset"].func(); T.ok(ns.addon.db.profile.card.pos == nil)
end)
test("scope switch keeps both profiles and copies nothing", function()
    ns.addon.db.profile.card.scale = 111
    ns.Options.SetCharacterProfile(true)
    T.ok(ns.Options.CharacterProfileOn())
    T.eq(ns.addon.db.profile.card.scale, 100, "character profile starts at defaults")
    ns.Options.SetCharacterProfile(false)
    T.eq(ns.addon.db.profile.card.scale, 111, "shared profile kept its value")
end)
test("plans page lists and removes plans; runs stay", function()
    local f = io.open("build/dontdothat.ct"); local s = f:read("*a"); f:close()
    T.ok(ns.App.ImportPlan(s)); ns.App.Start("DontDoThat")
    local g = ns.Options.Plans(2)
    T.ok(g.args.list.name():find("DontDoThat"))
    ns.Options.state.remove = "DontDoThat"
    g.args.remove.func()
    T.ok(ns.App.db.plans.DontDoThat == nil)
    T.ok(ns.App.Current(), "run still resolves its plan from the store")
end)
test("home start button needs an imported plan", function()
    local g = ns.Options.Home(1)
    ns.Options.state.pick = nil
    T.ok(g.args.start.disabled())
end)
test("home lists past runs with open, export and delete; hidden when there are none", function()
    local App, Options = ns.App, ns.Options
    local saved = App.db.runs
    App.db.runs = {}; App.db.currentByChar = {}
    local g = Options.Home(1)
    T.ok(g.args.runPick.hidden() and g.args.runOpen.hidden() and g.args.h_runs.hidden(), "nothing stored, nothing drawn")
    if ns.App.db.plans.DontDoThat == nil then
        local f = io.open("build/dontdothat.ct"); local s = f:read("*a"); f:close(); App.ImportPlan(s)
    end
    local first = assert(App.Start("DontDoThat")); App.End()
    local second = assert(App.Start("DontDoThat")); App.End()
    T.ok(not g.args.runPick.hidden(), "rows draw once runs exist")
    local values, order = g.args.runPick.values(), g.args.runPick.sorting()
    T.eq(#order, 2); T.ok(values[first.runId] and values[second.runId])
    T.ok(g.args.runOpen.disabled() and g.args.runExport.disabled() and g.args.runDelete.disabled(), "no run chosen")
    g.args.runPick.set(nil, first.runId)
    T.ok(not g.args.runOpen.disabled(), "an ended run opens")
    T.eq(g.args.runOpen.confirm(), nil, "no unfinished run to replace")
    g.args.runOpen.func()
    T.eq(App.Current().runId, first.runId, "the card shows the chosen run")
    local live = assert(App.Start("DontDoThat"))
    g.args.runPick.set(nil, first.runId)
    T.eq(g.args.runOpen.confirm(), nil, "viewing an ended run takes nothing from a live run")
    local live2 = assert(App.Start("DontDoThat"))
    g.args.runPick.set(nil, live.runId)
    T.ok(g.args.runOpen.confirm():find("current run leaves"), "asks before one unfinished run replaces another")
    g.args.runPick.set(nil, first.runId)
    local shown
    local show = ns.Export.Show
    ns.Export.Show = function(_, s) shown = s end
    g.args.runExport.func()
    ns.Export.Show = show
    T.ok(shown and shown:find("^!CT1!"), "exports the chosen run")
    local text = g.args.runDelete.confirm()
    T.ok(type(text) == "string" and text:find("^Delete the run") and text:find("DontDoThat"), "the question names the run: " .. tostring(text))
    g.args.runDelete.func()
    T.eq(App.db.runs[first.runId], nil); T.eq(Options.state.run, nil)
    g.args.runPick.set(nil, live2.runId)
    local other = App.Character
    App.Character = function() return "Someone-Else" end
    T.ok(g.args.runOpen.disabled(), "an unfinished run of another character cannot open")
    T.ok(not g.args.runExport.disabled() and not g.args.runDelete.disabled())
    App.Character = other
    App.db.runs = saved
end)
test("advanced run limit sets and prunes; default is 20", function()
    local App = ns.App
    local g = ns.Options.Advanced(4)
    local r = g.args.runLimit
    T.eq(r.min, 5); T.eq(r.max, 100); T.eq(r.width, 1.5)
    App.db.runLimit = nil
    T.eq(r.get(), 20)
    local saved, cur = App.db.runs, App.db.currentByChar
    App.db.runs, App.db.currentByChar = {}, {}
    for i = 1, 8 do App.db.runs["r" .. i] = { started = i, steps = {}, runId = "r" .. i } end
    r.set(nil, 7); T.eq(App.db.runLimit, 7); T.eq(r.get(), 7)
    local function count() local n = 0; for _ in pairs(App.db.runs) do n = n + 1 end return n end
    T.eq(count(), 8, "dragging the slider deletes nothing")
    r.set(nil, 15); r.set(nil, 5); r.set(nil, 7)
    T.eq(count(), 8, "not even when the drag passes a low value")
    App.PruneRuns()
    T.eq(count(), 7, "the limit applies when a run starts"); T.eq(App.db.runs.r1, nil, "the oldest went")
    App.db.runs, App.db.currentByChar = saved, cur
    T.eq(ns.defaults.global.runLimit, 20)
end)
test("no control uses a string confirm, which AceConfigDialog reads as a handler method name", function()
    local function walk(group, path)
        for key, w in pairs(group.args or {}) do
            local where = path .. "." .. key
            if w.confirm ~= nil then T.ok(type(w.confirm) ~= "string", where .. " has a string confirm") end
            if w.type == "group" then walk(w, where) end
        end
    end
    walk(ns.Options.Build(), "tree")
end)
test("past runs spacing hides with the list", function()
    local App = ns.App
    local saved = App.db.runs
    App.db.runs = {}
    local g = ns.Options.Home(1)
    T.ok(g.args.g3.hidden(), "no gap after an empty list")
    App.db.runs = saved
end)
test("about lists the commands", function()
    local g = ns.Options.About(5)
    T.ok(g.args.cmd_import and g.args.helpDiagnostics)
end)
finish()
