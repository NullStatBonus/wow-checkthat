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
finish()
