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
    T.eq(table.concat(order, ","), "home,plans,appearance,advanced,about,profiles")
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
test("Profiles page holds the standard control and names the profile in use", function()
    local g = ns.Options.Profiles(6)
    local m = g.args.manage
    T.ok(m and m.inline, "AceDBOptions control shown inline")
    T.eq(m.name, "Manage profiles")
    T.ok(m.args.choose and m.args.copyfrom and m.args.reset and m.args.delete and m.args.new, "choose, copy, reset, delete, new")
    T.ok(g.args.current.name():find("Profile in use: Default", 1, true))
    local reg = LibStub("AceConfigRegistry-3.0")
    T.ok(pcall(reg.ValidateOptionsTable, reg, ns.Options.Build(), "CheckThat"))
    T.ok(ns.Options.Advanced(4).args.charProfile == nil, "the old checkbox is gone")
end)
test("Profiles page without AceDBOptions keeps its purpose and profile line", function()
    local real = LibStub.libs["AceDBOptions-3.0"]
    LibStub.libs["AceDBOptions-3.0"] = nil
    T.finally(function() LibStub.libs["AceDBOptions-3.0"] = real end)
    local g = ns.Options.Profiles(6)
    T.ok(g.args.manage == nil); T.ok(g.args.intro and g.args.current)
end)
test("choosing another profile switches, keeps both, names it and keeps debug", function()
    local db, said = ns.addon.db, {}
    H.stub(ns.Slash, "Print", function(s) said[#said + 1] = s end)
    T.finally(function() db:SetProfile("Default"); pcall(db.DeleteProfile, db, "Alt", true) end)
    db.profile.card.scale = 111; db.profile.debug = true
    local m = ns.Options.Profiles(6).args.manage
    T.eq(m.args.choose.set, "SetProfile")
    m.handler[m.args.choose.set](m.handler, {}, "Alt") -- what the control's Existing profiles list calls
    T.eq(db:GetCurrentProfile(), "Alt")
    T.eq(db.profile.card.scale, 100, "new profile starts at defaults; nothing copied")
    T.eq(db.profile.debug, true, "debug recording kept across the switch")
    T.eq(said[#said], "Profile changed. Profile in use: Alt.")
    local found = false
    for _, e in ipairs(ns.App.db.log.entries or ns.App.db.log) do if tostring(e.msg or e):find("profile changed to Alt", 1, true) then found = true end end
    T.ok(found, "log line")
    T.ok(ns.Log.Report():find("  profile = Alt", 1, true), "debug report names it")
    T.ok(table.concat(ns.Slash.Run("status", {}), "\n"):find("Profile in use: Alt.", 1, true), "/ct status names it")
    db:SetProfile("Default")
    T.eq(db.profile.card.scale, 111, "Default kept its value")
end)
test("a change with no switch before it leaves debug to the profile", function()
    H.stub(ns.Slash, "Print", function() end)
    ns.addon.db.profile.debug = false
    ns.Settings.ProfileChanged(nil)
    T.eq(ns.addon.db.profile.debug, false)
end)
test("copy, reset and delete redraw the pages, refresh the CT macro and log a line", function()
    local db = ns.addon.db
    H.stub(ns.Slash, "Print", function() end)
    db:SetProfile("Src"); db:SetProfile("Gone"); db:SetProfile("Default") -- profiles to copy from and delete
    T.finally(function() db:SetProfile("Default"); for _, p in ipairs({ "Src", "Gone" }) do pcall(db.DeleteProfile, db, p, true) end end)
    local n, macro = 0, 0
    H.stub(ns.Options, "Notify", function() n = n + 1 end)
    H.stub(ns.Card, "FollowMacro", function(fresh) if fresh then macro = macro + 1 end end)
    local function logged(s)
        for _, e in ipairs(ns.App.db.log.entries or ns.App.db.log) do if tostring(e.msg or e):find(s, 1, true) then return true end end
        return false
    end
    db.profile.debug = true
    db:ResetProfile()
    T.eq(db.profile.debug, true, "reset keeps debug recording")
    T.eq(n, 1, "reset redraws"); T.eq(macro, 1, "reset refreshes the macro"); T.ok(logged("profile reset"))
    db:CopyProfile("Src")
    T.eq(db.profile.debug, true, "copy keeps debug recording")
    T.eq(n, 2, "copy redraws"); T.eq(macro, 2, "copy refreshes the macro"); T.ok(logged("profile copied from Src"))
    db:DeleteProfile("Gone")
    T.eq(n, 3, "delete redraws"); T.ok(logged("profile deleted Gone"))
    db:SetProfile("Src")
    T.ok(n >= 4, "a switch redraws"); T.eq(macro, 3, "a switch refreshes the macro")
end)
test("a bar in a profile name is doubled in chat, /ct status and the page", function()
    local db, said = ns.addon.db, {}
    H.stub(ns.Slash, "Print", function(s) said[#said + 1] = s end)
    T.finally(function() db:SetProfile("Default"); pcall(db.DeleteProfile, db, "a|cffff0000b", true) end)
    db:SetProfile("a|cffff0000b")
    T.eq(said[#said], "Profile changed. Profile in use: a||cffff0000b.")
    T.ok(table.concat(ns.Slash.Run("status", {}), "\n"):find("Profile in use: a||cffff0000b.", 1, true))
    T.ok(ns.Options.Profiles(6).args.current.name():find("a||cffff0000b", 1, true))
end)
test("each login names the profile in use", function()
    local said = {}
    H.stub(ns.Slash, "Print", function(s) said[#said + 1] = s end)
    H.stub(ns.Adapter, "After", function() end)
    ns.addon:OnEnable()
    T.eq(said[1], "Profile in use: Default.")
end)
test("the game's Settings window lists Profiles under CheckThat", function()
    local seen = {}
    ns.Options.RegisterPanels({ AddToBlizOptions = function(_, app, name, parent, key) seen[#seen + 1] = tostring(parent) .. "/" .. key end })
    T.eq(table.concat(seen, ","), "nil/home,CheckThat/plans,CheckThat/appearance,CheckThat/advanced,CheckThat/about,CheckThat/profiles")
end)
test("/ct settings profiles opens the Profiles page", function()
    local opened
    ns.Slash.Run("settings profiles", { open = function(p) opened = p end })
    T.eq(opened, "profiles")
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
    H.stub(App.db, "runs", {}); H.stub(App.db, "currentByChar", {})
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
    local seen, record = {}, ns.Log.Record
    ns.Log.Record = function(_, msg) seen[#seen + 1] = msg end
    local view = g.args.runOpen.confirm()
    T.ok(view and view:find("look at it") and view:find("stays"), "viewing an ended run still asks while a run is active")
    T.ok((function() for _, m in ipairs(seen) do if m:find("run open asked ", 1, true) then return true end end end)(), "the question is logged")
    g.args.runPick.set(nil, live.runId)
    T.eq(g.args.runOpen.confirm(), nil, "the current run opens without a question")
    g.args.runPick.set(nil, first.runId)
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
    T.ok((function() for _, m in ipairs(seen) do if m:find("run delete asked ", 1, true) then return true end end end)(), "the delete question is logged")
    ns.Log.Record = record
    g.args.runDelete.func()
    T.eq(App.db.runs[first.runId], nil); T.eq(Options.state.run, nil)
    g.args.runPick.set(nil, live2.runId)
    H.stub(App, "Character", function() return "Someone-Else" end)
    T.ok(g.args.runOpen.disabled(), "an unfinished run of another character cannot open")
    T.ok(not g.args.runExport.disabled() and not g.args.runDelete.disabled())
end)
test("advanced run limit sets and prunes; default is 20", function()
    local App = ns.App
    local g = ns.Options.Advanced(4)
    local r = g.args.runLimit
    T.eq(r.min, 5); T.eq(r.max, 100); T.eq(r.width, 1.5)
    App.db.runLimit = nil
    T.eq(r.get(), 20)
    H.stub(App.db, "runs", {}); H.stub(App.db, "currentByChar", {})
    for i = 1, 8 do App.db.runs["r" .. i] = { started = i, steps = {}, runId = "r" .. i } end
    r.set(nil, 7); T.eq(App.db.runLimit, 7); T.eq(r.get(), 7)
    local function count() local n = 0; for _ in pairs(App.db.runs) do n = n + 1 end return n end
    T.eq(count(), 8, "dragging the slider deletes nothing")
    r.set(nil, 15); r.set(nil, 5); r.set(nil, 7)
    T.eq(count(), 8, "not even when the drag passes a low value")
    App.PruneRuns()
    T.eq(count(), 7, "the limit applies when a run starts"); T.eq(App.db.runs.r1, nil, "the oldest went")
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
    H.stub(App.db, "runs", {})
    local g = ns.Options.Home(1)
    T.ok(g.args.g3.hidden(), "no gap after an empty list")
end)
test("about lists the commands", function()
    local g = ns.Options.About(5)
    T.ok(g.args.cmd_import and g.args.helpDiagnostics)
end)
-- Categories on Home
local function stp(id) return { id = id, title = id, action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } } end
local function importCats(n)
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "Cats", sections = {} }
    for i = 1, n do p.sections[i] = { id = "c" .. i, title = "Cat " .. i, steps = { stp("s" .. i .. "a"), stp("s" .. i .. "b") } } end
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p))))
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil; ns.App.db.ui.cleared = nil
    ns.Options.state.pick = "KeepThat"
end
test("home lists one checkbox per category in plan order, all checked, hidden for one category", function()
    importCats(3)
    local g = ns.Options.Home(1)
    T.eq(g.args.cat1.name(), "Cat 1: 2 steps"); T.eq(g.args.cat3.name(), "Cat 3: 2 steps")
    T.eq(g.args.cat1.hidden(), false); T.eq(g.args.cat4.hidden(), true, "no fourth category")
    T.eq(g.args.cat2.get(), true)
    g.args.cat2.set(nil, false)
    T.eq(g.args.cat2.get(), false); T.eq(ns.App.PickedIds("KeepThat")[2], "c3")
    T.eq(g.args.pickNone.hidden(), true, "two are still checked")
    importCats(1)
    T.eq(g.args.cat1.hidden(), true, "one category needs no choice")
end)
test("home pages more than 24 categories and picks each of them", function()
    importCats(30)
    ns.Options.state.catPage = nil
    local g = ns.Options.Home(1)
    T.eq(g.args.pickPage.hidden(), false); T.eq(g.args.pickPage.name():find("Showing 1 to 24 of 30", 1, true) ~= nil, true)
    T.eq(g.args.cat24.name(), "Cat 24: 2 steps"); T.eq(g.args.cat1.name(), "Cat 1: 2 steps")
    T.eq(g.args.pickPrev.disabled(), true); T.eq(g.args.pickNext.disabled(), false)
    g.args.pickNext.func()
    T.eq(g.args.cat1.name(), "Cat 25: 2 steps"); T.eq(g.args.cat6.name(), "Cat 30: 2 steps"); T.eq(g.args.cat7.hidden(), true)
    T.eq(g.args.pickNext.disabled(), true); T.ok(g.args.pickPage.name():find("Showing 25 to 30 of 30", 1, true))
    g.args.cat6.set(nil, false)
    T.eq(ns.App.db.ui.cleared.KeepThat.c30, true, "a category past 24 can be cleared")
    g.args.pick.set(nil, "KeepThat"); T.eq(ns.Options.state.catPage, nil, "another pick starts at the top")
    importCats(3)
    T.eq(g.args.pickPage.hidden(), true)
end)
test("home starts a run with the checked categories and refuses none", function()
    importCats(3)
    local g = ns.Options.Home(1)
    g.args.cat1.set(nil, false); g.args.cat3.set(nil, false)
    T.eq(g.args.start.disabled(), false)
    g.args.start.func()
    local run = ns.App.Current()
    T.eq(run.selected.c2, true); T.eq(run.selected.c1, nil); T.eq(run.steps.s1a.verdict, "deselected")
    g.args.cat2.set(nil, false)
    T.eq(g.args.start.disabled(), true, "nothing checked"); T.eq(g.args.pickNone.hidden(), false)
end)
test("home lists the categories of the current run with state words and counts", function()
    importCats(3)
    local run = assert(ns.App.Start("KeepThat"))
    local g = ns.Options.Home(1)
    T.eq(g.args.categories.hidden(), false)
    local text = g.args.categories.name()
    T.ok(text:find("Cat 1 (c1): untested, 0 passed, 0 failed, 2 open", 1, true), text)
    T.ok(text:find("Overall: untested, 0 passed, 0 failed, 6 open", 1, true), text)
    importCats(1); ns.App.Start("KeepThat")
    T.eq(g.args.categories.hidden(), true, "one category: nothing to list")
end)
test("the tree still validates with the category controls", function()
    local reg = LibStub("AceConfigRegistry-3.0")
    T.ok(pcall(reg.ValidateOptionsTable, reg, ns.Options.Build(), "CheckThat"))
end)

finish()
