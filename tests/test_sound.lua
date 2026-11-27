local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- Result sounds (#229), through the real addon against the stub client: each path plays its sound once, the setting
-- turns them off, and a client without PlaySoundFile records results as before.
local st = H.stubClient()
H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
CheckThatDB = nil
ns.addon:OnInitialize(); ns.addon:OnEnable()
ns.Card.HOLD = 0

local played = {}
local function listen()
    played = {}
    H.stub(_G, "PlaySoundFile", function(path, channel) played[#played + 1] = { path = path, channel = channel }; return true end)
    H.stub(ns.addon.db.profile, "debug", true)
    ns.addon.db.profile.card.sound = true
end
local function names()
    local out = {}
    for _, p in ipairs(played) do out[#out + 1] = p.path:match("([%w-]+)%.ogg$") end
    return out
end
local function logged(text)
    for _, e in ipairs(ns.Log.Entries()) do if e.msg:find(text, 1, true) then return true end end
    return false
end
local manual = function(id, extra)
    local s = { id = id, title = "Step " .. id, action = { kind = "manual", text = "Do it." }, expect = "It works.", verify = { "player" } }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end
local function runPlan(steps)
    ns.Card.EndHold()
    _G.KeepThatDB = { global = { log = { "[kt] boot" } } }
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "Sounds",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = steps } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p))))
    local run = assert(ns.App.Start("KeepThat"))
    ns.addon.db.profile.card.collapsed = false
    ns.Card.Show()
    return run, _G.CheckThatCard
end
local function kt(line) KeepThatDB.global.log[#KeepThatDB.global.log + 1] = line end
local function auto(id, extra)
    local s = { id = id, title = "Auto " .. id, auto = true, timeout = 20, action = { kind = "wait-event", text = "Go." }, expect = "e",
        verify = { "assertions" }, assertions = { { kind = "log", source = "debug", contains = "went " .. id } } }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

test("a result the player records plays tick, on the SFX channel, from CheckThat's own folder", function()
    listen()
    runPlan({ manual("a"), manual("b") })
    ns.Card.Verdict("pass")
    T.same(names(), { "tick" })
    T.eq(played[1].channel, "SFX")
    T.ok(played[1].path:find("^Interface\\AddOns\\CheckThat\\Media\\Sounds\\"), played[1].path)
    T.ok(logged("sound tick for a"), "the log says which sound played for which step")
end)

test("Partial, Fail and Skip from the card, and /ct pass from chat, play tick", function()
    listen()
    runPlan({ manual("a"), manual("b"), manual("c"), manual("d"), manual("e") })
    for _, v in ipairs({ "partial", "fail", "skip" }) do ns.Card.Verdict(v) end
    assert(_G.SlashCmdList["ACECONSOLE_CT"], "AceConsole registers the /ct handler")("pass")
    T.same(names(), { "tick", "tick", "tick", "tick" })
end)

test("CheckThat's own pass plays chime-up, its fail chime-down", function()
    listen()
    runPlan({ auto("a"), auto("b", { assertions = { { kind = "log", source = "debug", contains = "hit", count = { max = 1 } } } }), manual("c") })
    kt("went a"); T.ok(ns.Card.AutoSettle())
    T.same(names(), { "chime-up" })
    kt("hit"); kt("hit"); local a = ns.Card.AutoSettle()
    T.eq(a and a.verdict, "fail")
    T.same(names(), { "chime-up", "chime-down" })
    T.ok(logged("sound chime-down for b"))
end)

test("an unverified result plays attention: an automatic step at its timeout, and Pass without the evidence", function()
    listen()
    local t = 1000
    H.stub(ns.App.env, "time", function() return t end)
    runPlan({ auto("a", { timeout = 5 }), manual("b", { verify = { "player", "assertions" }, assertions = { { kind = "log", source = "debug", contains = "never" } } }), manual("c") })
    ns.App.Begin()
    t = t + 30
    local a = ns.Card.AutoSettle()
    T.eq(a and a.verdict, "unverified")
    T.same(names(), { "attention" })
    ns.Card.Verdict("skip")
    ns.Card.Verdict("pass")
    T.eq(names()[3], "attention", "Pass without the evidence")
end)

test("the run's last result plays finish in place of its own sound", function()
    listen()
    runPlan({ manual("a"), manual("b") })
    ns.Card.Verdict("pass"); ns.Card.Verdict("pass")
    T.same(names(), { "tick", "finish" })
    T.ok(logged("sound finish for b"))
end)

test("a hidden or collapsed card still plays", function()
    listen()
    local _, card = runPlan({ auto("a"), auto("b"), manual("c") })
    card:Hide()
    kt("went a"); T.ok(ns.Card.AutoSettle(), "a hidden card settles")
    ns.addon.db.profile.card.collapsed = true; ns.Card.Show()
    kt("went b"); T.ok(ns.Card.AutoSettle())
    ns.addon.db.profile.card.collapsed = false
    T.same(names(), { "chime-up", "chime-up" })
end)

test("steps that pass when the run starts play one chime together", function()
    listen()
    _G.KeepThatDB = { global = { log = { "[kt] ready" } } }
    local function async(id)
        return { id = id, title = id, auto = true, async = true, action = { kind = "manual", text = "Wait." }, expect = "e",
            verify = { "assertions" }, assertions = { { kind = "log", source = "debug", contains = "ready" } } }
    end
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "Start",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = { async("v1"), async("v2"), async("v3"), manual("m") } } } }
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    assert(ns.App.ImportPlan(assert(ns.Codec.Encode(p))))
    assert(ns.App.Start("KeepThat"))
    T.same(names(), { "chime-up" })
    T.ok(logged("sound chime-up for v1"))
end)

test("Play result sounds off plays and logs nothing; /ct sound still plays", function()
    listen()
    ns.Settings.Set("card.sound", "off")
    T.finally(function() ns.Settings.Set("card.sound", "on") end)
    runPlan({ manual("a"), manual("b") })
    ns.Log.Clear()
    ns.Card.Verdict("pass")
    T.same(names(), {})
    T.ok(not logged("sound tick"), "nothing logged")
    T.same(ns.Slash.Run("sound attention", {}), {})
    T.same(names(), { "attention" }); T.ok(logged("sound attention for preview"))
end)

test("/ct sound names the five sounds for an unknown name", function()
    listen()
    T.eq(ns.Slash.Run("sound loud", {})[1], "Usage: /ct sound tick, chime-up, chime-down, attention or finish.")
    T.same(names(), {})
end)

test("a client without PlaySoundFile records results as before and logs no sound", function()
    listen()
    H.stub(_G, "PlaySoundFile", nil)
    local run = runPlan({ manual("a"), manual("b") })
    ns.Log.Clear()
    T.ok(pcall(ns.Card.Verdict, "pass"))
    T.eq(run.steps.a.verdict, "pass")
    T.ok(not logged("sound "), "no sound line")
    T.eq(ns.Slash.Run("sound tick", {})[1], "This client cannot play sound files.")
    H.stub(_G, "PlaySoundFile", function() error("broken") end)
    T.ok(pcall(ns.Card.Verdict, "pass"), "a failing PlaySoundFile raises nothing")
    local ok, out = pcall(ns.Slash.Run, "sound tick", {})
    T.ok(ok, "the preview raises nothing either"); T.eq(ok and out[1], "This client cannot play sound files.")
end)

test("the debug report shows card.sound", function()
    ns.Settings.Set("card.sound", "off")
    T.ok(ns.Log.Report():find("card.sound = false", 1, true), "off")
    ns.Settings.Set("card.sound", "on")
    T.ok(ns.Log.Report():find("card.sound = true", 1, true), "on, the default")
end)

finish()
