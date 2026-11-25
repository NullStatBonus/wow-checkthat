-- The opt-in login self-check (issue 99): calls the entries imported plans name, with no run open.
local ns, test, T, finish, H = dofile("tests/harness.lua")()
local st = H.stubClient()
H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
local addon = ns.addon

local function plan(expect)
    return { kind = "plan", ct = 1, addon = "KeepThat", title = "KT",
        logs = { facts = { global = "CheckThatDB", path = "global.facts", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "kt.add", title = "Add", action = { kind = "manual", text = "t" }, expect = "e", auto = true,
              call = { addon = "KeepThat", entry = "add", args = { 2, 3 } }, verify = { "assertions" },
              assertions = { { kind = "log", source = "facts", equals = expect } } },
            { id = "kt.plain", title = "Plain", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } },
        } } } }
end

local function boot(expect, enabled)
    CheckThatDB = nil
    addon:OnInitialize()
    addon.db.profile.loginCheck = enabled
    ns.Facts.API().Entry("KeepThat", "add", function(a, b) return a + b end)
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(plan(expect)))))
    local said = {}
    ns.Slash.Print = function(t) said[#said + 1] = t end
    ns.Adapter.After = function(_, fn) fn() end
    return said
end

test("the setting is off by default", function()
    CheckThatDB = nil; addon:OnInitialize()
    T.eq(addon.db.profile.loginCheck, false)
end)

test("a matching entry check prints one line and records no fact", function()
    local said = boot("[KeepThat] entry.add=5", true)
    addon:OnEnable()
    T.eq(#said, 1); T.eq(said[1], "Self-check: 1 of 1 entry checks matched.")
    T.eq(#addon.db.global.facts, 0)
end)

test("a wrong expectation names the first miss", function()
    local said = boot("[KeepThat] entry.add=6", true)
    addon:OnEnable()
    T.eq(said[1], "Self-check: 0 of 1 entry checks matched. First miss: kt.add: [KeepThat] entry.add=5")
end)

test("a raw bar in the miss text is doubled for chat", function()
    local said = boot("[KeepThat] entry.add=5", true)
    ns.Facts.API().Entry("KeepThat", "add", function() return "|cffff0000x|r" end)
    addon:OnEnable()
    T.ok(said[1]:find("entry.add=||cffff0000x||r", 1, true), said[1])
end)

test("with the setting off nothing is called", function()
    local called = false
    local said = boot("[KeepThat] entry.add=5", false)
    ns.Facts.API().Entry("KeepThat", "add", function() called = true; return 5 end)
    addon:OnEnable()
    T.eq(#said, 0); T.eq(called, false)
end)

test("in combat the check is skipped and no entry runs", function()
    local called = false
    local said = boot("[KeepThat] entry.add=5", true)
    ns.Facts.API().Entry("KeepThat", "add", function() called = true; return 5 end)
    st.combat = true
    addon:OnEnable()
    st.combat = false
    T.eq(#said, 0); T.eq(called, false)
end)

finish()
