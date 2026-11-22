local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- Loads the real Ace libraries and checks the settings pages against AceConfig's own validator.
local st = H.stubClient()
H.loadToc(ns, "TestThat/TestThat_Vanilla.toc")
do local d = LibStub("AceConfigDialog-3.0"); d.frame.apps = {}; d.frame.closing = {} end
TestThatDB = nil
ns.addon:OnInitialize()

test("the tree validates and has the shared pages in order", function()
    local tree = ns.Options.Build()
    local reg = LibStub("AceConfigRegistry-3.0")
    T.ok(pcall(reg.ValidateOptionsTable, reg, tree, "TestThat"))
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
    local f = io.open("build/dontdothat.wtt"); local s = f:read("*a"); f:close()
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
test("about lists the commands", function()
    local g = ns.Options.About(5)
    T.ok(g.args.cmd_import and g.args.helpDiagnostics)
end)
finish()
