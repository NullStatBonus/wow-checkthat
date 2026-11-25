local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- Combat rules, played through the real addon and the real /ct handler against the stub client's model of
-- protected frames: no change to a protected frame in combat, a state driver that hides the Run button for
-- the whole of combat, and OnShow and OnHide that run on every real change.
local st = H.stubClient()
H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
local addon = ns.addon
CheckThatDB = nil
addon:OnInitialize(); addon:OnEnable()
local slash = assert(_G.SlashCmdList["ACECONSOLE_CT"], "AceConsole registers the /ct handler")
local function importKeepThat()
    local f = io.open("build/keepthat.ct"); local s = f:read("*a"); f:close()
    assert(ns.App.ImportPlan(s))
end
-- The client leaves combat: the state driver runs, then PLAYER_REGEN_ENABLED reaches the addon.
local function combatEnds() st.setCombat(false); LibStub("AceEvent-3.0").events:Fire("PLAYER_REGEN_ENABLED") end
local function macroOf() local _, ctx, step = ns.App.Current(); return step and ns.App.MacroText(step, ctx.plan) end
local function toStepWithCommands()
    for _ = 1, 30 do
        if macroOf() then return true end
        slash("skip")
    end
end

test("combat: the harness refuses protected changes in combat and anchors to the screen only", function()
    local b = CreateFrame("Button", "TestSecure", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    local plain = CreateFrame("Frame", "TestPlain", UIParent)
    b:SetPoint("LEFT", UIParent, "LEFT", 0, 0)
    T.ok(not pcall(b.SetPoint, b, "LEFT", plain, "RIGHT"), "no anchor to another frame")
    st.setCombat(true)
    for _, m in ipairs({ "Show", "Hide", "SetAttribute", "SetPoint", "ClearAllPoints" }) do
        T.ok(not pcall(b[m], b, "type", "macro"), m .. " on a protected frame in combat raises")
    end
    T.ok(pcall(plain.Hide, plain), "a plain frame changes in combat")
    st.setCombat(false)
    T.ok(pcall(b.Show, b))
end)

test("combat: the first open in combat builds nothing protected, and the Run button appears after combat", function()
    importKeepThat()
    st.setCombat(true)
    slash("start KeepThat")
    local card = _G.CheckThatCard
    T.ok(card and card:IsShown(), "the card opens in combat")
    T.ok(card.secure == false, "no protected button is built in combat")
    combatEnds()
    T.ok(card.secure, "built once combat ends")
end)

test("combat: a step change in combat never runs a stale macro", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    slash("start KeepThat")
    T.ok(toStepWithCommands(), "a step with commands")
    ns.Card.Refresh()
    local card, old = _G.CheckThatCard, macroOf()
    T.eq(st.click(card.secure), old, "the button runs the step's macro out of combat")
    st.setCombat(true)
    T.ok(not card.secure:IsShown(), "the state driver hides the button for combat")
    T.eq(st.click(card.secure), nil, "nothing to click in combat")
    slash("skip")
    T.eq(st.click(card.secure), nil, "still nothing to click after the step changed in combat")
    T.eq(card.secure.attrs.macrotext, old, "the protected button is not touched in combat")
    T.ok(card.pendingMacro, "the new macro waits for the end of combat")
    combatEnds()
    local new = macroOf()
    if new then
        T.ok(new ~= old, "the next step has its own macro")
        T.eq(st.click(card.secure), new, "after combat the button runs the new step's macro")
    else
        T.eq(st.click(card.secure), nil, "after combat a step without commands has no Run button")
    end
end)

test("combat: closing the card in combat leaves no Run button after combat", function()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    slash("start KeepThat")
    T.ok(toStepWithCommands(), "a step with commands")
    ns.Card.Refresh()
    local card = _G.CheckThatCard
    T.ok(st.click(card.secure), "the button is live before combat")
    st.setCombat(true)
    T.ok(pcall(card.Hide, card), "closing the card in combat does not raise")
    T.eq(st.click(card.secure), nil, "no click in combat")
    combatEnds()
    T.ok(not card.secure:IsShown(), "no Run button for a closed card after combat")
    T.eq(st.click(card.secure), nil)
    st.tick()
    T.ok(not card.secure:IsShown(), "and the game's state driver does not bring it back")
    slash("")  -- opens the card again
    T.ok(card:IsShown() and st.click(card.secure) == macroOf(), "opening the card brings the button back")
end)
test("combat: category commands in combat raise nothing and the Run button follows the step shown", function()
    importKeepThat()
    st.setCombat(false)
    slash("start KeepThat")
    local run = ns.App.Current()
    st.setCombat(true)
    local ok = true
    for _, cmd in ipairs({ "categories", "run " .. run.categories[2].id, "rerun " .. run.categories[1].id }) do
        ok = pcall(slash, cmd) and ok
    end
    T.ok(ok, "the commands raise no error in combat")
    combatEnds()
    local card = _G.CheckThatCard
    T.eq(card.secure.attrs.macrotext or "", macroOf() or "", "the Run button holds the macro of the step now shown")
end)

-- The CT macro follows the current step (setting macroFollow).
local function logHas(pat)
    local n = 0
    for _, e in ipairs(ns.Log.Entries()) do if e.msg:find(pat) then n = n + 1 end end
    return n
end
-- The CT macro body: the marker for the step on the card, then the commands.
local function marked(text) local _, _, step = ns.App.Current(); return "/ct macrorun " .. step.id .. "\n" .. text end
local function resetFollow(on)
    st.setCombat(false)
    st.macros, st.macroBody = {}, nil
    ns.App.db.ui.macroName, ns.App.db.ui.macroBody = nil, nil
    addon.db.profile.debug = true
    addon.db.profile.macroFollow = on
    ns.Log.Clear()
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    slash("start KeepThat")
end

test("follow: the CT macro takes the current step's commands on each step change", function()
    resetFollow(true)
    local seen, prev = 0, nil
    for _ = 1, 6 do
        local want = marked(macroOf() or "/ct status")
        T.eq(st.macroBody, want, "the macro holds the shown step")
        T.ok(not st.macroBody:find("/ct pass") and not st.macroBody:find("/ct fail")
            and not st.macroBody:find("/ct partial") and not st.macroBody:find("/ct skip"), "no result command")
        local _, _, step = ns.App.Current()
        T.ok(want == prev or logHas("macro set " .. step.id) >= 1, "a new body is logged for " .. step.id)
        seen, prev = seen + 1, want
        slash("skip")
    end
    T.eq(seen, 6)
end)

test("follow: a refresh with no step change writes and logs nothing", function()
    resetFollow(true)
    local n = logHas("macro set")
    ns.Card.Refresh(); ns.Card.Refresh()
    T.eq(logHas("macro set"), n)
end)

test("follow: the setting off leaves the macro alone", function()
    resetFollow(false)
    T.eq(st.macroBody, nil, "no macro made")
    slash("skip")
    T.eq(logHas("macro set"), 0)
end)

test("follow: turning the setting on sets the macro at once", function()
    resetFollow(false)
    addon.db.profile.macroFollow = true
    ns.Card.FollowMacro(true)
    T.eq(st.macroBody, marked(macroOf() or "/ct status"))
end)

test("follow: steps changed in combat wait; one rewrite after combat", function()
    resetFollow(true)
    local before = st.macroBody
    local n = logHas("macro set")
    st.setCombat(true)
    slash("skip"); slash("skip")
    T.eq(st.macroBody, before, "no macro edit in combat")
    T.eq(logHas("macro set"), n, "no log line in combat")
    combatEnds()
    T.eq(st.macroBody, marked(macroOf() or "/ct status"), "the latest step after combat")
    T.eq(logHas("macro set"), n + 1, "one rewrite")
end)

test("follow: a macro the player changed is left alone", function()
    resetFollow(true)
    st.macroBody = "/dance"
    local n = logHas("macro set")
    slash("skip")
    T.eq(st.macroBody, "/dance", "not edited")
    T.eq(logHas("macro set"), n)
    local created = 0
    for _ in pairs(st.macros) do created = created + 1 end
    T.eq(created, 1, "no second macro")
end)

test("follow: a new run takes back a macro the player changed, while the marker is there", function()
    resetFollow(true)
    st.macroBody = st.macroBody .. "\n/dance"
    slash("skip")
    T.ok(st.macroBody:find("/dance", 1, true), "an edit stays for the rest of the run")
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    slash("start KeepThat")
    T.eq(st.macroBody, marked(macroOf() or "/ct status"), "the new run takes the macro back")
    st.macroBody = st.macroBody .. "\n/dance"
    slash("skip")
    T.ok(st.macroBody:find("/dance", 1, true), "and an edit in that run stays again")
end)

test("follow: turning the setting on takes back a macro the player changed", function()
    resetFollow(true)
    st.macroBody = st.macroBody .. "\n/dance"
    addon.db.profile.macroFollow = false
    addon.db.profile.macroFollow = true
    ns.Card.FollowMacro(true)
    T.eq(st.macroBody, marked(macroOf() or "/ct status"))
end)

test("follow: a macro without the marker stays the player's in every run", function()
    resetFollow(true)
    st.macroBody = "/dance"
    ns.App.db.currentByChar = {}; ns.App.db.ui.pendingStart = nil
    slash("start KeepThat")
    ns.Card.FollowMacro(true)
    T.eq(st.macroBody, "/dance")
end)

test("follow: a step whose commands do not fit gets /ct status and a card line", function()
    resetFollow(true)
    local _, ctx, step = ns.App.Current()
    step.action = { kind = "manual", text = "x", commands = { "/ct status", "/ct status", "/ct status", "/ct status", "/ct status" } }
    ns.Card.Refresh()
    T.eq(st.macroBody, marked("/ct status"))
    T.ok(_G.CheckThatCard.hint:GetText():find("no macro"), "card line says so")
    step.action = { kind = "manual", text = "x" }
    ns.Card.Refresh()
    local h = _G.CheckThatCard.hint
    T.ok(not (h:IsShown() and (h:GetText() or ""):find("no macro")), "no line for a step without commands")
end)

test("follow: a result command in a step never reaches the macro", function()
    resetFollow(true)
    local _, _, step = ns.App.Current()
    local allow = ns.Plan.SLASH.KeepThat
    local had = allow["/checkthat"]; allow["/checkthat"] = true; allow["/ct"] = true
    for _, cmd in ipairs({ "/checkthat pass", "/ct Fail note", "/ct skip" }) do
        step.action = { kind = "manual", text = "x", commands = { "/ct status", cmd } }
        ns.Card.Refresh()
        T.eq(st.macroBody, marked("/ct status"), cmd)
    end
    allow["/checkthat"], allow["/ct"] = had, nil
end)

test("follow: a collapsed card and the end of combat still move the macro", function()
    resetFollow(true)
    local _, _, step = ns.App.Current()
    addon.db.profile.card.collapsed = true
    step.action = { kind = "manual", text = "x", commands = { "/kt log" } }
    ns.Card.Refresh()
    T.eq(st.macroBody, marked("/kt log"), "collapsed")
    st.setCombat(true)
    step.action = { kind = "manual", text = "x", commands = { "/kt log", "/reload" } }
    combatEnds()
    T.eq(st.macroBody, marked("/kt log\n/reload"), "after combat while collapsed")
    addon.db.profile.card.collapsed = false
end)

test("follow: /ct macro after a player edit makes a second macro even in a run", function()
    resetFollow(false)
    slash("macro")
    st.macroBody = "/dance"
    slash("macro")
    T.ok(st.macros.CT2, "CT2 made")
end)

test("follow: a refused edit keeps following", function()
    resetFollow(true)
    local _, _, step = ns.App.Current()
    local real = _G.EditMacro
    _G.EditMacro = function() end
    step.action = { kind = "manual", text = "x", commands = { "/kt log" } }
    local n = logHas("macro set")
    ns.Card.Refresh()
    T.eq(logHas("macro set"), n, "no false log line")
    _G.EditMacro = real
    ns.Card.Refresh()
    T.eq(st.macroBody, marked("/kt log"), "the next refresh writes it")
end)

-- A key press: the game runs each line of the macro body through /ct.
local function press()
    for line in (st.macroBody .. "\n"):gmatch("(.-)\n") do
        local cmd = line:match("^/ct%s+(.*)$")
        if cmd then slash(cmd) end
    end
end

test("follow: a press on the step the macro was written for logs macro run", function()
    resetFollow(true)
    local _, _, step = ns.App.Current()
    press()
    T.eq(logHas("macro run " .. step.id), 1)
    T.eq(logHas("macro stale"), 0)
end)

test("follow: a press after the step moved in combat logs macro stale", function()
    resetFollow(true)
    local _, _, old = ns.App.Current()
    st.setCombat(true)
    slash("skip")
    local _, _, cur = ns.App.Current()
    local said = {}
    local print0 = ns.Slash.Print; ns.Slash.Print = function(s) said[#said + 1] = s end
    press()
    ns.Slash.Print = print0
    T.eq(logHas("macro stale " .. old.id .. " card " .. cur.id), 1)
    T.eq(logHas("macro run"), 0)
    T.ok(said[1] and said[1]:find(old.id, 1, true) and said[1]:find(cur.id, 1, true), "chat names both steps")
    combatEnds()
end)

test("follow: setting off, then a press on a later step, logs macro stale", function()
    resetFollow(true)
    local _, _, old = ns.App.Current()
    addon.db.profile.macroFollow = false
    slash("skip")
    local _, _, cur = ns.App.Current()
    press()
    T.eq(logHas("macro stale " .. old.id .. " card " .. cur.id), 1)
end)

test("follow: the Run button never logs macro run", function()
    resetFollow(true)
    local card = _G.CheckThatCard
    toStepWithCommands(); ns.Card.Refresh()
    ns.Log.Clear()
    local run = st.click(card.secure)
    T.ok(run and not run:find("macrorun"), "Run holds the commands only")
    T.eq(logHas("macro run"), 0)
end)

test("follow: a body near the limit falls back to the marker and /ct status", function()
    resetFollow(true)
    local _, _, step = ns.App.Current()
    local long = "/kt log " .. ("x"):rep(255 - 8 - #("/ct macrorun " .. step.id) )
    step.action = { kind = "manual", text = "x", commands = { long } }
    ns.Card.Refresh()
    T.eq(st.macroBody, marked("/ct status"), "marker plus command is over 255")
    T.ok(_G.CheckThatCard.hint:GetText():find("no macro"))
    step.action = { kind = "manual", text = "x", commands = { "/kt log" } }
    ns.Card.Refresh()
    T.eq(st.macroBody, marked("/kt log"))
end)

test("follow: /ct macrorun needs one step id and records no result", function()
    resetFollow(true)
    local said = {}
    local print0 = ns.Slash.Print; ns.Slash.Print = function(s) said[#said + 1] = s end
    slash("macrorun"); slash("macrorun a b")
    ns.Slash.Print = print0
    T.eq(#said, 2, "usage line each time")
    T.ok(said[1]:find("Usage"))
    T.eq(logHas("macro run") + logHas("macro stale"), 0)
    local _, _, step = ns.App.Current()
    slash("macrorun " .. step.id)
    local _, _, still = ns.App.Current()
    T.eq(still.id, step.id, "no result, the card stays")
end)

test("follow: a macro without the marker logs nothing", function()
    resetFollow(true)
    st.macroBody = "/ct status"
    press()
    T.eq(logHas("macro run"), 0); T.eq(logHas("macro stale"), 0)
end)

test("follow: the setting is in the debug report", function()
    T.ok(ns.Log.Report():find("macroFollow = true", 1, true))
end)

finish()
