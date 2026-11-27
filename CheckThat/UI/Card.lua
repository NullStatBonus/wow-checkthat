-- The checklist card: one step at a time, copy boxes, the secure Run button, Pass / Fail / Skip / Undo.
-- Only the player's clicks do anything. Appearance comes from the profile (Core/Settings.lua).
local _, ns = ...
local L = ns.L
local App = ns.App
local Card = {}
ns.Card = Card

local card, text
local hold -- { id = step id } while an automatic result stays on screen (Card.Hold)
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
local A = ns.Adapter

local function cfg()
    return (ns.addon and ns.addon.db and ns.addon.db.profile.card) or ns.defaults.profile.card
end

local function makeButton(parent, label, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 64, 22)
    b:SetText(label)
    return b
end

local function copyBox(parent)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetAutoFocus(false); e:SetHeight(20); e:SetFontObject("ChatFontNormal")
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end) -- not the raw method: the game passes extra arguments
    e:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(self.value or ""); self:HighlightText() end -- read-only: typing, cuts and deletes revert
    end)
    function e:Set(v) self.value = v; self:SetText(v or ""); self:SetCursorPosition(0) end
    return e
end

-- The secure button is protected: the game refuses to anchor it to the card's regions or child frames.
-- It is anchored to the screen (UIParent) only, at coordinates read from the first command box after layout.
-- Never in combat; any failure is logged, never raised.
function Card.PlaceSecure()
    if not card or A.InCombat() or not card.secure then return end
    local anchor = card.secureAnchor
    if not (anchor and anchor:IsShown()) then return end
    local right, top, bottom = anchor:GetRight(), anchor:GetTop(), anchor:GetBottom()
    if type(right) ~= "number" or type(top) ~= "number" or type(bottom) ~= "number" then return end
    local s = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local ok, err = pcall(function()
        card.secure:ClearAllPoints()
        card.secure:SetPoint("LEFT", UIParent, "BOTTOMLEFT", (right + 8) * s, ((top + bottom) / 2) * s)
    end)
    if not ok and ns.Log then ns.Log.Failure("card", "could not place the Run button: " .. tostring(err)) end
end

-- Saved anchor, or the default when none is saved (reset position, profile switch).
function Card.ApplyPosition()
    if not card then return end
    local pos = cfg().pos
    card:ClearAllPoints()
    if pos then card:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else card:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0) end
end

-- Scale, fill opacity (pure black, nothing drawn at zero), text opacity and lock. Safe to call at any time.
function Card.ApplyAppearance()
    if not card then return end
    local c = cfg()
    card:SetScale((c.scale or 100) / 100)
    Card.PlaceSecure()
    local bg = (c.backgroundOpacity or 90) / 100
    if bg > 0 then card:SetBackdrop(BACKDROP); card:SetBackdropColor(0, 0, 0, bg); card:SetBackdropBorderColor(0.3, 0.3, 0.3, bg)
    else card:SetBackdrop(nil) end
    local ta = (c.textOpacity or 100) / 100
    for _, f in ipairs(card.texts or {}) do f:SetAlpha(ta) end
    for _, s in ipairs(card.segs or {}) do s.back:SetAlpha(ta); for _, t in ipairs(s.parts) do t:SetAlpha(ta) end end
    for _, t in ipairs(card.barParts) do t:SetAlpha(ta) end
    if card.caption then card.caption:SetAlpha(ta) end
    if ns.Tracker then ns.Tracker.ApplyAppearance() end
    if card.barMode then card.barBack:SetAlpha(ta); card.barFill:SetAlpha(ta) end
    -- Nothing is drawn at zero: redraw so a hidden or shown tracker follows the setting at once.
    if card.drawn and card:IsShown() and Card.Refresh then Card.Refresh() end
end

local INNER = 356
local GREY, BODY = { 0.67, 0.67, 0.67 }, { 0.87, 0.87, 0.87 }
local AMBER, GREEN, RED = { 1, 0.67, 0 }, { 0.6, 1, 0.6 }, { 1, 0.4, 0.4 }
local blindNow -- set below: does the step read the Lua error list while CheckThat cannot see errors?

-- The title is the strongest text on the card: the game's large font, two points larger, with an outline (game fonts
-- have no bold weight). Returns the font object's name; without CreateFont the stock large font stays.
function Card.TitleFont()
    if type(_G.CreateFont) ~= "function" then return "GameFontHighlightLarge" end
    local base = _G.GameFontHighlightLarge
    if type(base) ~= "table" then return "GameFontHighlightLarge" end
    local ok = pcall(function()
        local f = _G.CheckThatCardTitle or _G.CreateFont("CheckThatCardTitle")
        f:CopyFontObject(base)
        local path, size = base:GetFont()
        if type(path) == "string" and type(size) == "number" then f:SetFont(path, size + 2, "OUTLINE") end
    end)
    return ok and "CheckThatCardTitle" or "GameFontHighlightLarge"
end

local function fs(font, color, width, justify)
    local f = card:CreateFontString(nil, "OVERLAY", font)
    if color then f:SetTextColor(color[1], color[2], color[3]) end
    if width then f:SetWidth(width) end
    f:SetJustifyH(justify or "LEFT"); f:SetJustifyV("TOP")
    card.texts[#card.texts + 1] = f
    return f
end

-- One line (cut with an ellipsis by the game) or a few wrapped lines; never past the width the font string has.
local function fit(f, lines)
    f:SetWordWrap(lines > 1)
    f:SetMaxLines(lines)
end

local function place(frame, x, y, anchor)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", anchor or card, "TOPLEFT", x, -y)
end

-- Tracker colors by category state. Blue is untested (the card's progress blue), yellow is partial or unverified.
local STATE_COLOR = { red = { 0.9, 0.2, 0.2 }, yellow = { 1, 0.82, 0 }, green = { 0.1, 0.8, 0.1 }, blue = { 0.4, 0.7, 1 }, grey = { 0.5, 0.5, 0.5 }, off = { 0.3, 0.3, 0.3 } }
local STATE_TEXT = { red = RED, yellow = AMBER, green = GREEN, blue = { 0.5, 0.75, 1 }, grey = GREY, off = GREY }
Card.STATE_COLOR, Card.STATE_TEXT = STATE_COLOR, STATE_TEXT
Card.MAX_SEGMENTS = 8
local GAP = 2

-- The colored parts of a bar of width w: passed in green, partial or unverified in yellow, failed in red, left to
-- right. What is left over (untested, skipped) shows the track. A category with one failure among six passes is
-- mostly green with a red end, not all red.
local function parts(c, w)
    local out, x = {}, 0
    if not c or (c.total or 0) == 0 then return out end
    for _, p in ipairs({ { "green", c.pass or 0 }, { "yellow", (c.partial or 0) + (c.unverified or 0) }, { "red", c.fail or 0 } }) do
        local pw = math.floor(w * p[2] / c.total + 0.5)
        if p[2] > 0 then pw = math.max(pw, 1) end
        if pw > 0 then out[#out + 1] = { x = x, w = math.min(pw, w - x), state = p[1] }; x = x + pw end
    end
    return out
end
Card.Parts = parts

-- The tracker row for a run: nil with one category (the plain bar). Two to eight categories get one segment each,
-- with x and width in card units and the filled width. More than eight get one bar colored by the overall state.
-- Plan order, and unpicked categories keep their place, so adding one never moves the others.
function Card.Tracker(rows, overall, sum, inner)
    if not rows or #rows < 2 then return nil end
    if #rows > Card.MAX_SEGMENTS then
        return { mode = "bar", state = overall, parts = parts(sum, inner), open = sum.open }
    end
    local n = #rows
    local w = math.floor((inner - GAP * (n - 1)) / n)
    local segs = {}
    for i, row in ipairs(rows) do
        segs[i] = { x = (i - 1) * (w + GAP), w = w, parts = row.picked and parts(row.counts, w) or {}, state = row.state, picked = row.picked,
            open = row.counts.open, tip = App.CategoryLine(row) }
    end
    return { mode = "segments", segs = segs }
end

-- "1 failed · 4 of 8 done": the overall result in words, so the colors are never the only signal.
function Card.Caption(overall, sum)
    return L["%s · %d of %d passed"]:format(App.StatePhrase(overall, sum), sum.pass or 0, sum.total)
end



-- A result from a button or a bound key. The result is recorded first; a drawing error afterwards is logged,
-- never allowed to look like a stuck step.
function Card.Verdict(v)
    if hold then
        -- The press was meant for the step that just passed by itself; it never judges the next one.
        Card.EndHold()
        App.Log(("result %s ignored: the card was showing an automatic result"):format(v))
        ns.Slash.Print(L["CheckThat recorded that step by itself. The card now shows the next step."])
        Card.Refresh()
        return
    end
    local note = card.note:GetText()
    if note == "" then note = nil end
    pcall(function() card.note:SetText(""); card.note:ClearFocus() end)
    local _, _, step = App.Verdict(v, note)
    local ok, err = pcall(function() Card.AfterVerdict(step); Card.Refresh() end)
    if not ok and ns.Log then ns.Log.Failure("card", "after " .. v .. ": " .. tostring(err)) end
end

-- A bound key (Bindings.xml): the same as the button, only while the card shows a step with its verdict buttons.
function Card.KeyVerdict(v)
    local btn = card and card[v]
    local function seen(f) return f and (f.IsVisible and f:IsVisible() or (not f.IsVisible and f:IsShown())) end -- hidden UI (Alt+Z) hides its children
    if card and hold and seen(card) then return Card.Verdict(v) end -- the pause ends; the press judges nothing
    if not (card and seen(card) and seen(btn)) then
        App.Log(("key %s ignored: card not visible"):format(v))
        ns.Slash.Print(L["Open the checklist and show a step to record a result with a key."])
        return
    end
    App.Log(("key %s"):format(v)) -- before the verdict, so a step can check its own key press
    Card.Verdict(v)
end
_G.BINDING_HEADER_CHECKTHAT = "CheckThat"
_G.BINDING_NAME_CHECKTHAT_PASS = L["Pass"]
_G.BINDING_NAME_CHECKTHAT_PARTIAL = L["Partial"]
_G.BINDING_NAME_CHECKTHAT_FAIL = L["Fail"]
_G.BINDING_NAME_CHECKTHAT_SKIP = L["Skip"]
function CheckThat_Key(v) if ns.Card then ns.Card.KeyVerdict(v) end end

local function build()
    card = CreateFrame("Frame", "CheckThatCard", UIParent, "BackdropTemplate")
    card:SetSize(380, 300)
    card:SetMovable(true); card:EnableMouse(true); card:SetClampedToScreen(true); card:RegisterForDrag("LeftButton")
    card:SetScript("OnDragStart", function(self) if not cfg().locked then self:StartMoving() end end)
    card:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        cfg().pos = { p, rp, x, y }
        Card.PlaceSecure()
    end)
    card.texts, card.rows = {}, {}
    card.secureAnchor = false
    card.secure = false -- created out of combat by Card.EnsureSecure
    card.ticking = false

    -- Header: where we are, and the controls that always stay in the same place.
    card.head = fs("GameFontHighlightSmall", GREY, 120); card.head:SetPoint("TOPLEFT", 12, -9)
    -- The Run menu: a control right of the title with a dropdown arrow and a hover highlight. Shown only while a run is active.
    card.headBtn = CreateFrame("Button", nil, card)
    card.headBtn:SetSize(46, 18)
    card.headBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    card.headBtn:GetHighlightTexture():SetAlpha(0.35)
    card.headBtn.label = card.headBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.headBtn.label:SetPoint("LEFT", 4, 0); card.headBtn.label:SetText(L["Run"])
    card.texts[#card.texts + 1] = card.headBtn.label
    card.headBtn.arrow = card.headBtn:CreateTexture(nil, "OVERLAY")
    card.headBtn.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow"); card.headBtn.arrow:SetSize(10, 10)
    card.headBtn.arrow:SetRotation(-math.pi / 2)
    card.headBtn.arrow:SetPoint("LEFT", card.headBtn.label, "RIGHT", 3, 0)
    card.headBtn:SetScript("OnClick", function(self) Card.RunMenu(self) end)
    local close = CreateFrame("Button", nil, card, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 3, 3)
    local collapse = makeButton(card, "-", 22); collapse:SetPoint("RIGHT", close, "LEFT", 2, 0)
    collapse:SetScript("OnClick", function() cfg().collapsed = not cfg().collapsed; Card.Refresh() end)
    card.collapse = collapse
    -- Step navigation: < and > move through the steps (done steps can be redone).
    card.nextBtn = makeButton(card, ">", 22); card.nextBtn:SetPoint("RIGHT", collapse, "LEFT", -2, 0)
    card.nextBtn:SetScript("OnClick", function() Card.Go(1) end)
    card.prevBtn = makeButton(card, "<", 22); card.prevBtn:SetPoint("RIGHT", card.nextBtn, "LEFT", -1, 0)
    card.prevBtn:SetScript("OnClick", function() Card.Go(-1) end)
    for _, b in ipairs({ collapse, card.nextBtn, card.prevBtn }) do b:SetHeight(22) end
    card.nextBtn:SetWidth(24); card.prevBtn:SetWidth(24)

    -- Progress: a thin bar filled by resolved steps.
    card.barBack = card:CreateTexture(nil, "ARTWORK"); card.barBack:SetColorTexture(0.2, 0.2, 0.2, 1)
    card.barBack:SetPoint("TOPLEFT", 12, -26); card.barBack:SetSize(INNER, 3)
    card.barFill = card:CreateTexture(nil, "OVERLAY"); card.barFill:SetColorTexture(0.4, 0.7, 1, 1)
    card.barFill:SetPoint("TOPLEFT", 12, -26); card.barFill:SetSize(1, 3)

    -- The tracker: one segment per category (two to eight), a caption with the overall result in words, and the
    -- Categories list. The segments only show a tooltip: a click on a 3 unit bar would be too easy to miss or to hit by mistake.
    card.segs, card.barParts = {}, {}
    card.caption = fs("GameFontHighlightSmall", GREY, 250); card.caption:SetPoint("TOPLEFT", 12, -31)
    card.catBtn = CreateFrame("Button", nil, card)
    card.catBtn:SetSize(84, 18)
    card.catBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    card.catBtn:GetHighlightTexture():SetAlpha(0.35)
    card.catBtn.label = card.catBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.catBtn.label:SetPoint("RIGHT", -2, 0); card.catBtn.label:SetText(L["Categories"])
    card.texts[#card.texts + 1] = card.catBtn.label
    card.catBtn:SetPoint("TOPRIGHT", -12, -28)
    card.catBtn:SetScript("OnClick", function() ns.Tracker.Toggle() end)
    card.picks = {}
    card.pickNote = fs("GameFontHighlightSmall", GREY, 340)

    local titleFont = Card.TitleFont()
    card.titleFont = titleFont
    card.title = fs(titleFont, { 1, 1, 1 }, INNER)
    -- Over the collapsed title: shows the full text on hover and passes a drag on to the card.
    card.titleHit = CreateFrame("Frame", nil, card)
    card.titleHit:EnableMouse(true); card.titleHit:RegisterForDrag("LeftButton")
    card.titleHit:SetPoint("TOPLEFT", card.title, "TOPLEFT"); card.titleHit:SetPoint("BOTTOMRIGHT", card.title, "BOTTOMRIGHT")
    card.titleHit:SetScript("OnEnter", function(self) A.Tooltip(self, self.full) end)
    card.titleHit:SetScript("OnLeave", function() A.TooltipHide() end)
    for _, ev in ipairs({ "OnDragStart", "OnDragStop" }) do
        card.titleHit:SetScript(ev, function() local f = card:GetScript(ev); if f then f(card) end end)
    end
    card.context = fs("GameFontHighlightSmall", GREY, INNER)
    card.evidence = fs("GameFontHighlight", AMBER, INNER)
    card.hint = fs("GameFontHighlightSmall", GREY, INNER)
    card.noteLabel = fs("GameFontHighlightSmall", GREY, 46)
    card.noteLabel:SetText(L["Note"])
    card.tally = fs("GameFontHighlight", BODY, INNER)
    card.blocked = fs("GameFontHighlightSmall", GREY, INNER)
    card.checksHead = fs("GameFontHighlightSmall", GREEN, INNER)
    card.checks = fs("GameFontHighlight", BODY, INNER)
    -- The Setup fold: one line with + or -, a click opens or closes it.
    card.fold = CreateFrame("Button", nil, card)
    card.fold:SetSize(INNER, 16)
    card.fold.label = card.fold:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.fold.label:SetPoint("LEFT", 0, 0); card.fold.label:SetWidth(INNER); card.fold.label:SetJustifyH("LEFT")
    card.fold.label:SetWordWrap(false); card.fold.label:SetMaxLines(1)
    card.fold.label:SetTextColor(GREY[1], GREY[2], GREY[3])
    card.texts[#card.texts + 1] = card.fold.label
    card.fold:SetScript("OnClick", function(self) Card.ToggleSetup(self.key); Card.Refresh() end)
    -- The note opens from one line, so a step without a note shows no empty box.
    card.addNote = CreateFrame("Button", nil, card)
    card.addNote:SetSize(120, 18)
    card.addNote:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    card.addNote.label = card.addNote:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.addNote.label:SetPoint("LEFT", 2, 0); card.addNote.label:SetText(L["+ Add note"])
    card.addNote.label:SetTextColor(GREY[1], GREY[2], GREY[3])
    card.texts[#card.texts + 1] = card.addNote.label
    card.addNote:SetScript("OnClick", function() card.noteOpen = true; Card.Refresh(); pcall(function() card.note:SetFocus() end) end)
    card.acts, card.setupOpen = {}, {}
    card.recorded = fs("GameFontHighlight", BODY, INNER)
    card.redo = makeButton(card, L["Redo this step"], 120); card.redo:SetHeight(24)
    card.redo:SetPoint("BOTTOMLEFT", 12, 12)
    card.redo:SetScript("OnClick", function() App.Begin(); Card.Refresh() end)

    card.copies = {}
    for i = 1, 4 do card.copies[i] = copyBox(card); card.copies[i]:SetWidth(190) end
    Card.EnsureSecure()
    card:HookScript("OnHide", function()
        if A.InCombat() or not card.secure then return end
        -- Release the state driver too, or it shows the button again beside no card.
        card.secureWanted = false
        if card.combatHide ~= false then card.combatHide = false; A.ReleaseCombatHide(card.secure) end
        card.secure:Hide()
    end)
    card:HookScript("OnShow", function() Card.Refresh() end)

    card.note = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
    card.note:SetAutoFocus(false); card.note:SetHeight(20); card.note:SetWidth(296); card.note:SetFontObject("ChatFontNormal")
    card.note:SetMaxLetters(200)
    card.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    card.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Pinned verdict row: fixed positions, native buttons.
    -- Pass, Partial (mostly works), Fail, Skip: one row, fixed places; Undo at the right.
    card.pass = makeButton(card, L["Pass"], 56); card.partial = makeButton(card, L["Partial"], 56)
    card.fail = makeButton(card, L["Fail"], 56); card.skip = makeButton(card, L["Skip"], 56)
    card.undo = makeButton(card, L["Undo"], 48)
    for _, b in ipairs({ card.pass, card.partial, card.fail, card.skip, card.undo }) do b:SetHeight(24) end
    card.pass:SetPoint("BOTTOMLEFT", 12, 12); card.partial:SetPoint("LEFT", card.pass, "RIGHT", 4, 0)
    card.fail:SetPoint("LEFT", card.partial, "RIGHT", 4, 0); card.skip:SetPoint("LEFT", card.fail, "RIGHT", 4, 0)
    card.undo:SetPoint("BOTTOMRIGHT", -12, 12)
    for k, v in pairs({ pass = "pass", partial = "partial", fail = "fail", skip = "skip" }) do
        card[k]:SetScript("OnClick", function() Card.Verdict(v) end)
    end
    card.undo:SetScript("OnClick", function() App.Undo(); Card.Refresh() end)

    card.mainBtn = makeButton(card, L["Main window"], 110); card.mainBtn:SetHeight(24)
    card.mainBtn:SetScript("OnClick", function()
        -- Back to the card's start screen: show the finished run's plan with Start run and Import a plan.
        local run = App.Current()
        local addon = run and App.db.plans[run.addon] and run.addon or App.db.ui.lastImport
        if addon and App.db.plans[addon] then App.db.ui.pendingStart = addon end
        Card.Refresh()
    end)
    card.exportBtn = makeButton(card, L["Export results"], 110); card.exportBtn:SetHeight(24)
    card.exportBtn:SetScript("OnClick", function() Card.ExportNow() end)

    card.start = makeButton(card, L["Start run"], 100); card.start:SetHeight(24)
    card.start:SetPoint("BOTTOMLEFT", 12, 12)
    card.start:SetScript("OnClick", function()
        local addon = App.db.ui.pendingStart or App.db.ui.lastImport
        local run, err = App.Start(addon, App.PickedIds(addon))
        if not run then ns.Slash.Print(err) elseif ns.Picker then ns.Picker.Hide() end
        Card.Refresh()
    end)
    card.importAgain = makeButton(card, L["Import a plan"], 112); card.importAgain:SetHeight(24)
    card.importAgain:SetPoint("LEFT", card.start, "RIGHT", 6, 0)
    card.importAgain:SetScript("OnClick", Card.ImportPrompt)
    card.chooseBtn = makeButton(card, L["Choose categories"], 140); card.chooseBtn:SetHeight(24)
    card.chooseBtn:SetScript("OnClick", function()
        if ns.Picker then ns.Picker.Show(App.db.ui.pendingStart or App.db.ui.lastImport) end
    end)
    card.resume = makeButton(card, L["Resume run"], 100); card.resume:SetHeight(24)
    card.resume:SetPoint("LEFT", card.importAgain, "RIGHT", 6, 0)
    card.resume:SetScript("OnClick", function() App.db.ui.pendingStart = nil; Card.Refresh() end)

    -- Label column rows: Setup / Do / Expect.
    for i = 1, 3 do
        local label = fs("GameFontHighlightSmall", GREY, 46)
        local text = fs("GameFontHighlight", BODY, 298)
        card.rows[i] = { label = label, body = text }
    end
    Card.ApplyPosition()
    Card.ApplyAppearance()
end

-- The secure button is its own top-level frame, so it never makes the card a protected parent: the card can
-- move, resize and hide in combat. The button is created, changed and shown out of combat only. A state driver
-- hides it for the whole of combat, so a stale macro can never be clicked.
function Card.EnsureSecure()
    if card.secure then return card.secure end
    if A.InCombat() then return nil end
    local s = CreateFrame("Button", "CheckThatSecureButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    s:SetSize(56, 24); s:SetText(L["Run"])
    s:SetFrameStrata("DIALOG")
    s:SetAttribute("type", "macro")
    s:SetAttribute("useOnKeyDown", false)
    s:RegisterForClicks("AnyUp")
    A.HideInCombat(s); card.combatHide = true
    -- The game's own state driver shows this button again after combat. It must show only with a step that has commands.
    s:HookScript("OnShow", function(self)
        if A.InCombat() or card.secureWanted then return end -- protected in combat; fine when a step wants it
        self:Hide()
        local _, _, cur = App.Current()
        -- The state driver shows the button about five times a second. One line for each screen is enough.
        local msg = "run button hidden: nothing to run on this screen (step " .. (cur and cur.id or "none") .. ")"
        if card.hiddenLogged ~= msg then card.hiddenLogged = msg; App.Log(msg) end
    end)
    s:Hide()
    card.secure = s
    return s
end

local function setMacro(step, plan)
    local body = App.MacroText(step, plan)
    local s = not A.InCombat() and Card.EnsureSecure()
    if not s then card.pendingMacro = true; return end -- in combat: the button is hidden (state driver) and is set up after combat
    card.pendingMacro = nil
    card.secureWanted = body and card:IsShown() and true or false
    if card.secureWanted then card.hiddenLogged = nil end
    if card.secureWanted then
        if not card.combatHide then card.combatHide = true; A.HideInCombat(s) end -- the driver hides it for the whole of combat
        s:SetAttribute("macrotext", body); s:Show()
    else
        -- The driver would show the button again every 0.2 seconds. Out of combat it is safe to release it while unused.
        if card.combatHide ~= false then card.combatHide = false; A.ReleaseCombatHide(s) end
        s:SetAttribute("macrotext", ""); s:Hide()
    end
end

-- A plan can ask for evidence to be shared at a point: a reload (logs reach saved variables) or the export string.
function Card.AfterVerdict(step)
    if not step then return end
    if step.share == "export" then Card.ExportNow()
    elseif step.share == "reload" then
        ns.Slash.Print(L["This plan asks for a reload now so the log reaches the saved file. Type /reload."])
        local run = App.Current()
        App.db.ui.shareReload = run and run.runId or nil -- belongs to this run; cleared when the UI loads again
    end
end

-- Ask first, then end the current run. The answer re-checks that the run is still the same one.
function Card.ConfirmEnd()
    local run, err = App.CanEnd()
    if not run then ns.Slash.Print(err); return end
    local runId = run.runId
    local shown = A.Confirm(L["End this run? Your recorded results will be kept. You cannot resume this run."], function()
        local ended, why = App.End(runId)
        if ended then ns.Slash.Print(L["Run ended."]) else ns.Slash.Print(why) end
        Card.Refresh()
    end)
    if not shown then ns.Slash.Print(L["The confirmation window is not available. The run stays active."]) end
end

-- Ask first, then end the run and forget its plan. The results stay for export.
function Card.ConfirmClear()
    local run, err = App.CanEnd()
    if not run then ns.Slash.Print(err); return end
    local runId = run.runId
    local plan = App.db.planStore[run.planDigest or ""]
    local name = ns.Slash.Esc(plan and plan.title or run.addon):gsub("%%", "%%%%") -- the dialog formats its text
    local shown = A.Confirm(L["Clear the plan %s? The run ends, your recorded results stay for export, and the plan leaves your loaded and recent plans."]:format(name), function()
        local cleared, why = App.ClearPlan(runId)
        if cleared then ns.Slash.Print(L["Plan cleared. The run ended."]) else ns.Slash.Print(why) end
        if ns.Options and ns.Options.Notify then ns.Options.Notify() end
        Card.Refresh()
    end)
    if not shown then ns.Slash.Print(L["The confirmation window is not available. The run stays active."]) end
end

-- The Run menu. Where the game has no menu API, a click on the control asks to end the run directly.
function Card.RunMenu(owner)
    local items = { { L["Import..."], Card.ImportPrompt }, { L["End run..."], Card.ConfirmEnd }, { L["Clear plan..."], Card.ConfirmClear } }
    if not A.ContextMenu(owner, items) then Card.ConfirmEnd() end
end

function Card.ExportNow(runId)
    local s, err = App.Export(runId)
    if s then ns.Export.Show(L["Results string"], s) else ns.Slash.Print(err) end
end

function Card.ImportPrompt()
    local function choose(digest)
        local plan, err = App.UseRecent(digest)
        if plan then
            ns.Slash.Print(L["Using %s."]:format(ns.Slash.Esc(plan.title)))
            Card.Show()
            if ns.Options and ns.Options.Notify then ns.Options.Notify() end
            Card.Refresh()
        else ns.Slash.Print(err) end
    end
    ns.Export.Prompt(L["Paste a plan string (it starts with !CT1!), or pick a recent plan"], "", function(str)
        local plan, err = App.ImportPlan(str)
        if plan then
            ns.Slash.Print(L["Imported %s."]:format(ns.Slash.Esc(plan.title)))
            App.db.ui.lastImport = plan.addon
            Card.Show() -- the window opens as soon as a plan is imported
        else ns.Slash.Print(L["Import failed. %s"]:format(err)) end
        if ns.Options and ns.Options.Notify then ns.Options.Notify() end
        Card.Refresh()
    end, L["Import"], nil, nil, { choices = App.Recent(), onChoose = choose })
end

-- Evidence explanations are English for the log and the report; the card shows a translated sentence.
local WHY = {
    ["no matching log line"] = L["no matching log line"],
    ["log not readable (is debug on and the addon loaded?)"] = L["the log cannot be read; turn debug on and check the addon is loaded"],
    ["log rolled over; evidence lost"] = L["the log rolled over"],
    ["no new log lines (is debug on?)"] = L["no new log lines; turn debug on"],
    ["value unavailable"] = L["the value is not available"],
}

local function hideAll()
    for _, e in ipairs(card.copies) do e:Hide() end
    for _, k in ipairs({ "pass", "partial", "fail", "skip", "undo", "note", "start", "importAgain", "exportBtn", "noteLabel", "evidence", "hint", "tally", "context", "pickNote", "chooseBtn", "title", "resume", "blocked", "checksHead", "fold", "addNote", "checks", "recorded", "redo", "prevBtn", "nextBtn", "mainBtn", "headBtn", "titleHit" }) do card[k]:Hide() end
    for _, r in ipairs(card.rows) do r.label:Hide(); r.body:Hide() end
    card.barBack:Hide(); card.barFill:Hide(); card.caption:Hide(); card.catBtn:Hide()
    for _, s in ipairs(card.segs) do s.back:Hide(); for _, t in ipairs(s.parts) do t:Hide() end; s.hit:Hide() end
    for _, t in ipairs(card.barParts) do t:Hide() end
    for _, p in ipairs(card.picks) do p.check:Hide(); p.label:Hide() end
    for _, r in ipairs(card.acts) do r.box:Hide(); r.label:Hide(); r.hit:Hide() end
    card.secureWanted = false
    if not A.InCombat() and card.secure then card.secure:Hide() end
end

local function setText(f, str, color)
    f:SetText(str or "")
    if color then f:SetTextColor(color[1], color[2], color[3]) end
    f:Show()
end

-- A note belongs to one attempt of one step; the box is cleared when this key changes.
local function noteKeyOf(run, step, rec) return run.runId .. "/" .. step.id .. "/" .. #rec.attempts end

-- Draws the tracker and its caption. Returns how far the content moves down (the caption row), 0 with one category.
-- Draws the colored parts of a bar into a list of textures (made on demand), at x from the card's left, 3 high.
local function drawParts(list, ps, x0, ta)
    for i = 1, 3 do if list[i] then list[i]:Hide() end end
    for i, p in ipairs(ps) do
        local t = list[i]
        if not t then t = card:CreateTexture(nil, "OVERLAY"); list[i] = t end
        local col = STATE_COLOR[p.state]
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", x0 + p.x, -26); t:SetSize(p.w, 3)
        t:SetColorTexture(col[1], col[2], col[3], 1); t:SetAlpha(ta)
        if ta > 0 then t:Show() end
    end
end

function Card.DrawTracker(tracker, rows, overall, sum, inner, mini, resolved, total)
    local ta = (cfg().textOpacity or 100) / 100
    if not tracker then
        -- One category: the plain bar, as before.
        card.barMode = false
        card.barBack:SetAlpha(1); card.barFill:SetAlpha(1)
        card.barBack:SetColorTexture(0.2, 0.2, 0.2, 1)
        card.barBack:SetWidth(inner); card.barBack:Show(); card.barFill:Show()
        card.barFill:SetColorTexture(0.4, 0.7, 1, 1)
        card.barFill:SetWidth(math.max(1, inner * (total > 0 and resolved / total or 0)))
        return 0
    end
    card.caption:SetWidth(mini and inner or 250)
    setText(card.caption, Card.Caption(overall, sum), STATE_TEXT[overall])
    if not mini then card.catBtn:Show() end
    if tracker.mode == "bar" then
        local blue = STATE_COLOR.blue
        if tracker.open > 0 then card.barBack:SetColorTexture(blue[1] * 0.3, blue[2] * 0.3, blue[3] * 0.3, 1) else card.barBack:SetColorTexture(0.25, 0.25, 0.25, 1) end
        card.barBack:SetWidth(inner); card.barBack:SetAlpha(ta); card.barMode = true
        card.barFill:Hide()
        drawParts(card.barParts, tracker.parts, 12, ta)
        if ta > 0 then card.barBack:Show() end
        return 12
    end
    for i, seg in ipairs(tracker.segs) do
        local s = card.segs[i]
        if not s then
            s = { back = card:CreateTexture(nil, "ARTWORK"), parts = {}, hit = CreateFrame("Frame", nil, card) }
            s.hit:EnableMouse(true); s.hit:RegisterForDrag("LeftButton")
            s.hit:SetScript("OnEnter", function(self) A.Tooltip(self, self.tip) end)
            s.hit:SetScript("OnLeave", function() A.TooltipHide() end)
            for _, ev in ipairs({ "OnDragStart", "OnDragStop" }) do
                s.hit:SetScript(ev, function() local f = card:GetScript(ev); if f then f(card) end end)
            end
            card.segs[i] = s
        end
        s.back:ClearAllPoints(); s.back:SetPoint("TOPLEFT", 12 + seg.x, -26); s.back:SetSize(seg.w, 3)
        -- The track behind the colored parts: a dim blue while steps are untested, grey when none are, and darker for a
        -- category that is not picked.
        local blue = STATE_COLOR.blue
        if not seg.picked then s.back:SetColorTexture(0.2, 0.2, 0.2, 1)
        elseif seg.open > 0 then s.back:SetColorTexture(blue[1] * 0.3, blue[2] * 0.3, blue[3] * 0.3, 1)
        else s.back:SetColorTexture(0.25, 0.25, 0.25, 1) end
        s.back:SetAlpha(ta)
        drawParts(s.parts, seg.parts, 12 + seg.x, ta)
        s.hit:ClearAllPoints(); s.hit:SetPoint("TOPLEFT", 12 + seg.x, -23); s.hit:SetSize(seg.w, 9)
        s.hit.tip = seg.tip
        s.hit:Show()
        if ta > 0 then s.back:Show() end
    end
    return 12
end

-- The items for one category: add it, go to its first open step, or rerun it.
function Card.CategoryItems(r)
    local id, items = r.id, {}
    if not r.picked then
        items[#items + 1] = { L["Add to run: %s"]:format(r.title), function() local _, err = App.Select(id); if err then ns.Slash.Print(err) end; Card.Refresh() end }
        return items
    end
    if r.counts.open > 0 then
        items[#items + 1] = { L["Go to first open step: %s"]:format(r.title), function()
            local kind, err = App.Trigger(id); if not kind then ns.Slash.Print(err) end; Card.Refresh() end }
    end
    if r.counts.resolved > 0 then
        items[#items + 1] = { L["Rerun category: %s"]:format(r.title), function() Card.AskRerun(id) end }
    end
    if App.CanDeselect(id) then
        items[#items + 1] = { L["Remove from run: %s"]:format(r.title), function()
            local ok, err = App.Deselect(id); if not ok then ns.Slash.Print(err) end; Card.Refresh() end }
    end
    return items
end

function Card.AskRerun(id)
    local n, title = App.RerunCount(id)
    if not n then ns.Slash.Print(title); return end
    if n == 0 then ns.Slash.Print(App.NothingToReopen(id, title)); return end
    Card.ConfirmRerun(id, n, title)
end

-- Ask first: a rerun reopens recorded results and takes them out of Undo. Earlier attempts stay in the export.
function Card.ConfirmRerun(id, n, title)
    local safe = tostring(title):gsub("%%", "%%%%") -- the dialog formats its text
    local asked = App.Current()
    local runId = asked and asked.runId
    local ask
    if id == ns.Run.FAILED then
        ask = n == 1 and L["Rerun the 1 failed or unverified step? Earlier attempts stay in the export."]
            or L["Rerun the %d failed or unverified steps? Earlier attempts stay in the export."]:format(n)
    elseif n == 1 then ask = L["Rerun %s? This reopens 1 completed step. Earlier attempts stay in the export."]:format(safe)
    else ask = L["Rerun %s? This reopens %d completed steps. Earlier attempts stay in the export."]:format(safe, n) end
    local shown = A.Confirm(ask, function()
        local now = App.Current()
        if not (now and now.runId == runId) then ns.Slash.Print(L["The run on the card changed. Nothing was reopened."]); return end
        local reopened, why = App.Rerun(id)
        if not reopened then ns.Slash.Print(why)
        elseif id == ns.Run.FAILED then
            ns.Slash.Print(reopened == 1 and L["Reopened 1 failed or unverified step."] or L["Reopened %d failed or unverified steps."]:format(reopened))
        elseif reopened == 1 then ns.Slash.Print(L["Reopened 1 step in %s."]:format(ns.Slash.Esc(title)))
        else ns.Slash.Print(L["Reopened %d steps in %s."]:format(reopened, ns.Slash.Esc(title))) end
        Card.Refresh()
    end)
    if not shown then ns.Slash.Print(L["The confirmation window is not available. The run stays as it is."]) end
end

local function makePick(i)
    local p = {}
    p.check = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
    p.check:SetSize(24, 24)
    p.check:SetScript("OnClick", function(self) App.SetPick(self.addon, self.cat, self:GetChecked() and true or false); Card.Refresh() end)
    p.label = fs("GameFontHighlight", BODY, 300)
    card.picks[i] = p
    return p
end

-- One listed action: a standard checkbox and its label; a click on either toggles it. Without the checkbox template a
-- text button shows [ ] or [x]. A tick goes to the run (App.Tick); the box always shows what the run holds.
function Card.MakeAction(i)
    local row = {}
    local ok, box = pcall(CreateFrame, "CheckButton", nil, card, "UICheckButtonTemplate")
    local isCheck = ok and box and box.SetChecked ~= nil
    if isCheck then box:SetSize(24, 24)
    else
        box = CreateFrame("Button", nil, card); box:SetSize(24, 18)
        box.mark = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); box.mark:SetPoint("CENTER")
        card.texts[#card.texts + 1] = box.mark
    end
    row.box = box
    row.label = fs("GameFontHighlight", BODY, 280)
    row.hit = CreateFrame("Button", nil, card)
    row.hit:SetPoint("TOPLEFT", row.label, "TOPLEFT"); row.hit:SetPoint("BOTTOMRIGHT", row.label, "BOTTOMRIGHT")
    local function toggle()
        if row.locked then if isCheck then box:SetChecked(row.on) end return end
        App.Tick(i, not row.on); Card.Refresh()
    end
    box:SetScript("OnClick", toggle); row.hit:SetScript("OnClick", toggle)
    function row.set(on, locked)
        row.locked = locked
        if isCheck then
            box:SetChecked(on)
            if locked then box:Disable() else box:Enable() end
        else box.mark:SetText(on and "[x]" or "[ ]") end
    end
    card.acts[i] = row
    return row
end

-- Is the Setup fold of this step open? The first time a step shows in a run it opens by itself; then the player decides.
-- What was seen is kept for the current run only, so it survives a reload without growing.
function Card.SetupOpen(key)
    local ui = App.db.ui
    local runId = key:match("^(.-)/") or ""
    if type(ui.setupSeen) ~= "table" or ui.setupSeen.run ~= runId then ui.setupSeen = { run = runId, ids = {} } end
    if card.setupOpen[key] == nil then
        card.setupOpen[key] = not ui.setupSeen.ids[key]
        ui.setupSeen.ids[key] = true
    end
    return card.setupOpen[key]
end
function Card.ToggleSetup(key) if key then card.setupOpen[key] = not Card.SetupOpen(key) end end

-- After an automatic result the card keeps the recorded step on screen and fades to the next step (Card.HOLD seconds).
-- A press on the card or a result key ends it. Without timers there is no hold.
Card.HOLD, Card.FADE_STEPS = 3, 6
function Card.EndHold()
    if not card then return end
    hold = nil
    card:SetAlpha(1)
end
function Card.Hold(stepId)
    if Card.HOLD <= 0 then return false end
    local h = { id = stepId }
    hold = h
    if not A.After(Card.HOLD, function() if hold == h then Card.EndHold(); Card.Refresh() end end) then hold = nil; return false end
    for i = 1, Card.FADE_STEPS - 1 do
        A.After(Card.HOLD * i / Card.FADE_STEPS, function() if hold == h then card:SetAlpha(1 - 0.6 * i / Card.FADE_STEPS) end end)
    end
    App.Log(("card holds %s for %d s"):format(stepId, Card.HOLD))
    return true
end

local refreshCard
function Card.Refresh()
    refreshCard()
    if ns.Tracker then ns.Tracker.Refresh() end
    if ns.Picker then
        if not (card and card.chooseBtn:IsShown()) then ns.Picker.Hide() end -- only the start screen of a plan with many categories uses it
        ns.Picker.Refresh()
    end
end
function refreshCard()
    Card.FollowMacro() -- first: also while the card is collapsed, hidden or not built
    if not card then return end
    if not card:IsShown() and card.secure and not A.InCombat() then card.secure:Hide() end
    local run, ctx, step = App.Current()
    -- While an automatic result is held on screen, the card shows that step, read-only, and not the next one.
    local held = hold and run and ctx and ns.Run.stepOf(ctx, hold.id)
    if hold and (not held or run.endedAt) then Card.EndHold(); held = nil end -- an ended run shows its results at once
    if held then step = held end
    hideAll()
    local collapsed = cfg().collapsed
    local pendingAddon = App.db.ui.pendingStart
    local starting = not run or (pendingAddon and App.db.plans[pendingAddon]) -- the start screen is always full width
    local mini = collapsed and run and not starting
    card:SetWidth(mini and 280 or 380)
    local inner = mini and 256 or INNER
    card.title:SetWidth(inner); card.barBack:SetWidth(inner)
    fit(card.title, mini and 1 or 2)
    card.collapse:SetText(collapsed and "+" or "-")
    card.head:SetText(L["CheckThat"])
    if run and not run.endedAt and not starting then
        card.headBtn:ClearAllPoints(); card.headBtn:SetPoint("LEFT", card.head, "LEFT", card.head:GetStringWidth() + 4, 0) -- same line centre as the title
        card.headBtn:Show()
    end
    if starting then
        -- A plan is waiting to start (just imported or picked): it takes focus, even after a finished run.
        local rec = (pendingAddon or App.db.ui.lastImport) and App.db.plans[pendingAddon or App.db.ui.lastImport]
        place(card.title, 12, 36)
        local y, msg
        if rec then
            local steps = 0
            for _, s in ipairs(rec.plan.sections) do steps = steps + #s.steps end
            setText(card.title, rec.plan.title)
            card.titleHit.full = rec.plan.title; card.titleHit:Show() -- the full title on hover, as in the collapsed card
            msg = steps == 1 and L["1 step. Ready to test. Select Start run."] or L["%d steps. Ready to test. Select Start run."]:format(steps)
            card.start:Show()
        else
            setText(card.title, L["No plan yet"])
            msg = L["Select Import a plan and paste a plan string."]
        end
        y = 36 + card.title:GetStringHeight() + 8
        place(card.context, 12, y); setText(card.context, msg, BODY)
        y = y + card.context:GetStringHeight() + 12
        card.start:SetEnabled(true)
        local list = rec and App.Picks(pendingAddon or App.db.ui.lastImport) or {}
        if #list > 1 and #list <= Card.MAX_SEGMENTS then
            -- Choose what to run: one checkbox per category, all checked until the tester clears one.
            local any = false
            for i, ch in ipairs(list) do
                local p = card.picks[i] or makePick(i)
                p.check.addon, p.check.cat = pendingAddon or App.db.ui.lastImport, ch.id
                p.check:SetChecked(ch.picked)
                place(p.check, 10, y - 4); place(p.label, 38, y + 1)
                p.check:Show()
                setText(p.label, ch.steps == 1 and L["%s: 1 step"]:format(ch.title) or L["%s: %d steps"]:format(ch.title, ch.steps), BODY)
                if ch.picked and ch.steps > 0 then any = true end
                y = y + 24
            end
            if not any then
                place(card.pickNote, 12, y + 2); setText(card.pickNote, L["Select at least one category."], AMBER)
                y = y + card.pickNote:GetStringHeight() + 8
                card.start:SetEnabled(false)
            end
        elseif #list > Card.MAX_SEGMENTS then
            -- Too many for the card: a count and a button that opens the picker window.
            local any, n, runnable = false, 0, 0
            for _, ch in ipairs(list) do
                if ch.steps > 0 then runnable = runnable + 1 end
                if ch.picked and ch.steps > 0 then any = true; n = n + 1 end
            end
            place(card.pickNote, 12, y)
            setText(card.pickNote, any and L["%d of %d categories picked."]:format(n, runnable) or L["Select at least one category."], any and GREY or AMBER)
            y = y + card.pickNote:GetStringHeight() + 6
            card.chooseBtn:ClearAllPoints(); card.chooseBtn:SetPoint("TOPLEFT", 12, -y); card.chooseBtn:Show()
            y = y + 30
            card.start:SetEnabled(any)
            if ns.Picker then ns.Picker.Follow(pendingAddon or App.db.ui.lastImport) end
        end
        card.start:ClearAllPoints(); card.start:SetPoint("BOTTOMLEFT", 12, 12)
        card.importAgain:ClearAllPoints() -- the first visible button sits at the left edge
        if rec then card.importAgain:SetPoint("LEFT", card.start, "RIGHT", 6, 0) else card.importAgain:SetPoint("BOTTOMLEFT", 12, 12) end
        card.importAgain:Show()
        if run and step then card.resume:Show() end -- an unfinished run can still be resumed
        card:SetHeight(y + 36); return
    end
    local total = #run.order
    for _, id in ipairs(run.order) do if run.steps[id].verdict == "inapplicable" then total = total - 1 end end -- not for this character: out of progress
    local c = ns.Run.Counts(run)
    local resolved = total - (c.open or c.pending or 0)
    local rows, overall, sum = App.Categories()
    card.drawn = true
    local tracker = Card.Tracker(rows, overall, sum, inner)
    local top = Card.DrawTracker(tracker, rows, overall, sum, inner, mini, resolved, total)
    if collapsed then
        local r0 = step and run.steps[step.id]
        if r0 and (r0.verdict == "pending" or r0.verdict == "unverified") then App.Begin() end -- arm evidence and the auto timer while collapsed
        local shownTitle = step and step.title or (run.endedAt and L["Run ended"] or L["Run complete"])
        place(card.title, 12, 32 + top); setText(card.title, shownTitle)
        card.titleHit.full = shownTitle; card.titleHit:Show()
        card:SetHeight(40 + top + math.min(card.title:GetStringHeight(), 36)); return
    end
    if not step then
        -- Results and handoff. An ended run shows the same screen, with nothing to undo or step through.
        local ended = run.endedAt
        place(card.title, 12, 36 + top); setText(card.title, ended and L["Run ended"] or L["Run complete"])
        local y = 36 + top + card.title:GetStringHeight() + 6
        place(card.tally, 12, y); setText(card.tally, L["%d passed   %d partial   %d failed   %d skipped"]:format(c.pass, c.partial, c.fail, c.skip), BODY)
        y = y + card.tally:GetStringHeight() + 8
        place(card.context, 12, y)
        local ask = App.db.ui.shareReload == run.runId and not ended -- the last step asked for a reload so the log reaches the saved file
        setText(card.context, L["Export results to share this run. The game saves the evidence to disk when you reload or log out."] .. "\n" .. (ended and "" or ctx.plan.handoff or "")
            .. (ask and ("\n" .. L["Type /reload now so the game saves the log."]) or ""), GREY)
        y = y + card.context:GetStringHeight() + 12
        if not ended then card.prevBtn:Show() end
        card.exportBtn:ClearAllPoints(); card.exportBtn:SetPoint("BOTTOMLEFT", 12, 12); card.exportBtn:Show()
        -- Main window goes back to the loaded plan. With no plan loaded it would show the same screen, so Import a plan takes its place.
        local loaded = App.db.plans[run.addon] or (App.db.ui.lastImport and App.db.plans[App.db.ui.lastImport])
        local second = loaded and card.mainBtn or card.importAgain
        second:ClearAllPoints(); second:SetPoint("LEFT", card.exportBtn, "RIGHT", 6, 0); second:Show()
        if not ended then card.undo:Show() end
        card:SetHeight(y + 36); return
    end
    local rec0 = run.steps[step.id]
    local resolved = rec0.verdict ~= "pending" and rec0.verdict ~= "unverified"
    if not resolved then
        local _, _, unmet = App.Begin() -- arm evidence before the tester acts
        if unmet then return refreshCard() end -- not for this character: the run moved on
    end
    local lastA = rec0.attempts[#rec0.attempts]
    local open = lastA and not lastA.verdict and lastA or nil
    local viewing = resolved and not open -- a finished step is read-only until Redo
    local holding = hold ~= nil -- an automatic result stays on screen while the card fades to the next step
    local reloaded = open and open.reloaded
    local required = {}
    for _, a in ipairs(step.assertions or {}) do
        if not a.diagnostic then required[#required + 1] = a end
    end
    card.prevBtn:Show(); card.nextBtn:Show()
    local y = 36 + top
    place(card.title, 12, y); setText(card.title, step.title)
    y = y + card.title:GetStringHeight() + 6
    local autoLive = step.auto and not (open and open.noauto) -- after an automatic unverified result the retry waits for the player
    -- Setup folds to one line. It holds the step's setup, the plan's preamble at the start and the section intro, and
    -- opens by itself the first time the step shows in this run.
    local extra = {}
    if step.setup then extra[#extra + 1] = step.setup end
    if ctx.plan.preamble and App.AtStart(run) then extra[#extra + 1] = L["Before you start: %s"]:format(ctx.plan.preamble:sub(1, 300)) end
    local intro = App.SectionIntro(run, ctx, step.id)
    if intro then extra[#extra + 1] = L["This section: %s"]:format(intro:sub(1, 240)) end
    if #extra > 0 and not viewing then
        local key = run.runId .. "/" .. step.id
        local opened = Card.SetupOpen(key)
        card.fold.key = key
        local first = extra[1]:match("^(.-[%.!?])%s") or extra[1]
        card.fold.label:SetText((opened and L["- Setup: %s"] or L["+ Setup: %s"]):format(first)) -- one line: the game ends a longer one with "..."
        place(card.fold, 12, y); card.fold:Show()
        y = y + 18
        if opened then
            place(card.context, 24, y); setText(card.context, table.concat(extra, "\n"), BODY)
            y = y + card.context:GetStringHeight() + 8
        end
    end
    local blocked = ns.Run.Blocked(ctx, step)
    if #blocked > 0 and not viewing then
        place(card.blocked, 12, y); setText(card.blocked, L["Blocked: %s"]:format(table.concat(blocked, "; ")), GREY)
        y = y + card.blocked:GetStringHeight() + 8
    end
    -- Do: one sentence, or one checkbox for each listed action. The player ticks them; a tick is never a result.
    local acts = type(step.action.text) == "table" and step.action.text or nil
    local doRow, exRow = card.rows[2], card.rows[3]
    place(doRow.label, 12, y + 2); setText(doRow.label, L["Do"], GREY)
    if acts then
        local ticks = (open or lastA or {}).ticks or {}
        for i, t in ipairs(acts) do
            local row = card.acts[i] or Card.MakeAction(i)
            local on = ticks[i] and true or false
            row.on = on
            row.set(on, not open or holding)
            place(row.box, 56, y - 4); row.box:Show()
            place(row.label, 82, y); setText(row.label, t, on and { 1, 1, 1 } or BODY)
            row.hit:Show()
            y = y + math.max(row.label:GetStringHeight(), 16) + 6
        end
    else
        place(doRow.body, 62, y)
        setText(doRow.body, step.action.text or (step.action.kind == "wait-event" and (autoLive and L["Wait. CheckThat records the result when the checks below are met."] or L["Repeat the action, then press Pass."])) or L["Use the command below."], BODY)
        y = y + doRow.body:GetStringHeight() + 6
    end
    local copies = App.Copyables(step, ctx.plan)
    local firstCopy
    if not viewing then
        for k, e in ipairs(card.copies) do
            if copies[k] then
                e:Set(copies[k]); place(e, 66, y); e:Show()
                firstCopy = firstCopy or e
                y = y + 26
            end
        end
    end
    -- Hints belong to the action: a reload, a screenshot, the macro that does not fit.
    local hint = {}
    if reloaded then hint[#hint + 1] = L["|cff99ff99Reloaded.|r Check the result now, then record it."] end
    if not viewing then
        if step.screenshot then hint[#hint + 1] = L["Press Print Screen while the result is on screen."] end
        if step.reload == "after_action" and not reloaded then hint[#hint + 1] = L["Type /reload when done. This step resumes after."] end
        if App.db.ui.shareReload == run.runId then hint[#hint + 1] = L["Type /reload now so the game saves the log."] end
        local _, _, noMacro = Card.MacroBody()
        if ns.addon.db.profile.macroFollow and noMacro then
            hint[#hint + 1] = L["This step has no macro: its commands do not fit in one."]
        end
    end
    if #hint > 0 then place(card.hint, 62, y); setText(card.hint, table.concat(hint, " "), GREY); y = y + card.hint:GetStringHeight() + 6 end
    y = y + 4
    -- Expect: one sentence, or one short line for each listed result.
    place(exRow.label, 12, y + 2); setText(exRow.label, L["Expect"], GREY)
    local ex = step.expect
    place(exRow.body, 62, y)
    setText(exRow.body, type(ex) == "table" and ("- " .. table.concat(ex, "\n- ")) or ex, BODY)
    y = y + exRow.body:GetStringHeight() + 10
    -- Live checks, under a small heading that says CheckThat checks them. A step with none is the player's step.
    card.checkStep = nil
    if #required > 0 and open then
        card.checkStep = step.id
        place(card.checksHead, 12, y)
        setText(card.checksHead, autoLive and L["CheckThat checks and records the result"] or L["CheckThat checks"], GREEN)
        y = y + card.checksHead:GetStringHeight() + 4
        place(card.checks, 12, y); card.checks:Show()
        local items, left = ns.Run.Preview(run, ctx, step.id), App.TimeLeft()
        local blind = blindNow(ctx, items) and true or false
        card.blindShown = blind
        card.checks:SetText(Card.ChecksText(items, true, left or 0, blind)) -- measure the longest state so a green list never grows into the buttons
        y = y + card.checks:GetStringHeight() + 14
        card.checks:SetText(Card.ChecksText(items, false, left, blind))
    end
    if viewing then
        -- A finished step: show what was recorded, offer Redo. Nothing here changes the result.
        local word = ({ pass = L["Pass"], partial = L["Partial"], fail = L["Fail"], skip = L["Skip"] })[rec0.verdict] or rec0.verdict
        local last = lastA
        local line
        if rec0.verdict == "inapplicable" then line = L["Does not apply: %s"]:format(rec0.unmet or L["this step is for the other client."])
        elseif last and last.at == "start" then line = L["Recorded: %s (checked by CheckThat when the run started)"]:format(word)
        elseif last and last.by == "auto" then line = L["Recorded: %s (recorded by CheckThat)"]:format(word)
        else line = L["Recorded: %s"]:format(word) end
        place(card.recorded, 12, y)
        setText(card.recorded, line .. ((last and last.note) and ("  -  " .. last.note) or ""), holding and GREEN or BODY)
        y = y + card.recorded:GetStringHeight() + 12
        if not holding and rec0.verdict ~= "inapplicable" then card.redo:Show() end -- a rerun checks a step that does not apply again
        card:SetHeight(y + 40); return
    end
    -- Evidence status: amber only when something is missing.
    if rec0.verdict == "unverified" then
        local why
        local prev = rec0.attempts[#rec0.attempts - 1]
        for _, o in ipairs(prev and prev.outcomes or {}) do if o.result ~= "pass" and not o.diagnostic then why = o.why; break end end
        place(card.evidence, 12, y)
        setText(card.evidence, L["Unverified: %s. Repeat the action and press Pass again. Fail or Skip moves on."]:format(why and (WHY[why] or L["see the report"]) or L["no detail"]), AMBER)
        y = y + card.evidence:GetStringHeight() + 6
    end
    y = y + 6
    -- The note: one "Add note" line until the player opens it, or the attempt already has text in it.
    local noteKey = noteKeyOf(run, step, rec0)
    if card.noteKey ~= noteKey then card.note:SetText(""); card.noteKey = noteKey; card.noteOpen = false end -- a note belongs to one step attempt
    if card.noteOpen or card.note:GetText() ~= "" then
        card.noteLabel:Show(); place(card.noteLabel, 12, y + 3)
        place(card.note, 62, y - 1); card.note:Show()
        y = y + 34
    else
        place(card.addNote, 10, y); card.addNote:Show()
        y = y + 26
    end
    for _, k in ipairs({ "pass", "partial", "fail", "skip", "undo" }) do card[k]:Show() end
    -- The secure button sits beside the first command. A reload is the player's /reload, or the Run button of a step that lists it.
    card.secureAnchor = firstCopy or false
    setMacro(step, ctx.plan)
    Card.PlaceSecure()
    A.After(0.2, Card.PlaceSecure) -- layout settles a moment after the first show
    card:SetHeight(y + 40)
end

-- < and >: move the viewed step. Logged, and a drawing error is recorded instead of looking like a dead button.
function Card.Go(delta)
    if card and hold then Card.EndHold() end
    local before = App.Current() and select(3, App.Current())
    local moved = App.Goto(delta)
    local _, _, step = App.Current()
    App.Log(("go %s: %s -> %s (position %s)"):format(delta < 0 and "back" or "next", before and before.id or "-", step and step.id or "results", tostring(moved)))
    local ok, err = pcall(Card.Refresh)
    if not ok and ns.Log then ns.Log.Failure("card", "after go: " .. tostring(err)) end
end

-- The live check list: icon and label per required check.
local ICON = {
    met = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t",
    waiting = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14|t",
    bad = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t",
    later = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14|t",
}
local TINT = { met = "|cff66ff66", waiting = "|cffdddddd", bad = "|cffff6666", later = "|cffaaaaaa" }

-- reserve = true adds the final "all detected" line, so the card can be sized for the longest state.
-- left = seconds until an auto step settles itself, shown as the last line.
function Card.ChecksText(items, reserve, left, blind)
    local lines, allMet = {}, #items > 0
    for _, it in ipairs(items) do
        local a = it.assertion
        local label = it.label
        if not label then
            if a.kind == "log-sequence" then label = L["Matching lines in the debug log, in order"]
            elseif a.kind == "state" then label = L["The game state matches"]
            elseif a.kind == "fact" then label = L["A fact from the addon matches"]
            else label = L["A matching line in the debug log"] end
        end
        if it.state ~= "met" then allMet = false end
        local tail = it.state == "later" and ("  " .. L["(checked when you press Pass)"]) or ""
        lines[#lines + 1] = ICON[it.state] .. " " .. TINT[it.state] .. label .. tail .. "|r"
    end
    if allMet or reserve then lines[#lines + 1] = L["|cff66ff66All checks detected. Press Pass.|r"] end
    if blind then lines[#lines + 1] = L["|cffffaa00CheckThat cannot detect new Lua errors.|r"] end
    if left then lines[#lines + 1] = L["CheckThat records the result in %d s."]:format(left) end
    return table.concat(lines, "\n")
end

-- Does a check of these read the Lua error list? Only then the card warns that CheckThat cannot see errors.
local function readsErrors(ctx, items)
    for _, it in ipairs(items) do
        local src = it.assertion and it.assertion.source
        local def = src and ctx.plan.logs and ctx.plan.logs[src]
        if def and def.global == "CheckThatDB" and def.path == "global.errors" then return true end
    end
    return false
end
blindNow = function(ctx, items) return ns.Errors ~= nil and readsErrors(ctx, items) and ns.Errors.Blind() end

-- Re-reads the live checks of the current step; the loop in Show calls it twice a second.
function Card.UpdateChecks()
    if ns.Errors and card and card:IsShown() then ns.Errors.Watch() end -- another addon may have taken the handler
    if not (card and card:IsShown() and card.checkStep) then return end
    local run, ctx, step = App.Current()
    if run and step and step.id == card.checkStep then
        if ns.Errors then ns.Errors.Sample() end
        local items = ns.Run.Preview(run, ctx, step.id)
        local blind = blindNow(ctx, items) and true or false
        if blind ~= card.blindShown then Card.Refresh(); return end -- the warning changes the height: lay the card out again
        card.checks:SetText(Card.ChecksText(items, false, App.TimeLeft(), blind))
    end
end

-- Auto steps: the runner records the result itself once the checks say so. It reads only, and only while the card
-- is shown. An error here is logged and never stops the loop.
function Card.AutoSettle()
    if not card then return nil end
    -- A shown card is visible only while the game UI is shown. A hidden card settles unless the game UI is hidden too.
    if card:IsShown() then if not card:IsVisible() then return nil end
    elseif not UIParent:IsShown() then return nil end
    local pending = App.db.ui.pendingStart
    if pending and App.db.plans[pending] then return nil end -- the Start screen is showing, not the run
    if hold then return nil end -- the next step opens when the hold ends, so its timer starts when the player sees it
    local note = card.note and card.note:GetText()
    if note == "" then note = nil end
    local run, _, cur = App.Current()
    local rec = run and cur and run.steps[cur.id]
    if note and not (rec and card.noteKey == noteKeyOf(run, cur, rec)) then note = nil end -- the box may still hold another step's note
    local ok, a, step = pcall(App.AutoSettle, note)
    if not ok then
        if ns.Log then ns.Log.Failure("card", "auto settle: " .. tostring(a)) end
        return nil
    end
    if a then
        pcall(function() card.note:SetText(""); card.note:ClearFocus() end) -- the note went with the result
        -- Pause only when the run moved on: an unverified result keeps the step open for the player.
        local _, _, now = App.Current()
        if a.verdict ~= "unverified" and not (now and now.id == step.id) and card:IsShown() and not cfg().collapsed then pcall(Card.Hold, step.id) end
        local ok2, err = pcall(function() Card.AfterVerdict(step); Card.Refresh() end)
        if not ok2 and ns.Log then ns.Log.Failure("card", "after auto: " .. tostring(err)) end
    end
    return a
end

local function openAuto()
    local run, _, step = App.Current()
    return run and step and step.auto
end

-- Runs while the card is shown or an auto step is current. Stops itself otherwise; Card.Refresh restarts it.
local function tick()
    if not (card and (card:IsShown() or openAuto())) then if card then card.ticking = false end return end
    Card.AutoSettle()
    Card.UpdateChecks()
    A.After(0.5, tick)
end

local function kick()
    if card and not card.ticking then card.ticking = true; A.After(0.5, tick) end
end

function Card.Show()
    if not card then build() end
    card:Show(); Card.Refresh()
    kick()
end
function Card.Toggle() if card and card:IsShown() then card:Hide() else Card.Show() end end

-- Make the CT macro hold the current step's commands (or /ct status). Never in combat. Never overwrites a macro
-- the player made or changed. follow: a changed macro is left alone and no second one is made; returns nil.
-- Returns the macro name, and true when the game was told to change it.
-- reclaim: a macro the player changed is taken back when its first line is still our marker.
local function writeMacro(body, follow, silent, reclaim)
    local ui = App.db.ui
    local name, idx = ui.macroName, nil
    if name then
        idx = A.MacroIndex(name)
        if idx > 0 and A.MacroBody(idx) ~= ui.macroBody then -- the player changed it
            local ours = reclaim and (A.MacroBody(idx) or ""):find("^/ct macrorun ")
            if not ours then
                if follow then return nil end
                idx = 0
            end
        end
        if idx == 0 then idx, name = nil, nil end
    end
    if idx then
        if follow and A.MacroBody(idx) == body then ui.macroBody = body; return name, false end
        A.EditMacro(idx, name, body)
        if A.MacroBody(idx) ~= body then return nil end -- the game did not take it: keep the saved body
    else
        for n = 1, 9 do
            local cand = n == 1 and "CT" or ("CT" .. n)
            if A.MacroIndex(cand) == 0 then name = cand; break end
        end
        if not name then if not silent then ns.Slash.Print(L["No free macro name between CT and CT9."]) end; return nil end
        if not A.CreateMacro(name, body) then if not silent then ns.Slash.Print(L["The macro could not be created. The macro slots may be full."]) end; return nil end
    end
    ui.macroName, ui.macroBody = name, body
    return name, true
end

-- The CT macro starts with /ct macrorun <step id>, so a press says which step the macro was written for. A macro
-- never records a result: a body with a result command (/ct pass, /checkthat fail ...) gets /ct status instead.
local function hasResult(body)
    for line in (body .. "\n"):gmatch("(.-)\n") do
        local cmd, sub = line:lower():match("^(/%S+)%s+(%S+)")
        if (cmd == "/ct" or cmd == "/checkthat") and (sub == "pass" or sub == "partial" or sub == "fail" or sub == "skip") then return true end
    end
end
local MACRO_CHARS = 255 -- the game's limit for a macro body
-- Returns the body, the step, and true when the step has commands that no macro can hold. The Run button never
-- gets the marker: it runs App.MacroText.
function Card.MacroBody()
    local _, ctx, step = App.Current()
    if not step then return "/ct status" end
    local marker = "/ct macrorun " .. step.id
    local cmds = App.MacroText(step, ctx.plan)
    local fits = cmds and #marker + 1 + #cmds <= MACRO_CHARS
    if fits and not hasResult(cmds) then return marker .. "\n" .. cmds, step, false end
    return marker .. "\n/ct status", step, not fits and #App.Copyables(step, ctx.plan) > 0
end

-- Create or update the macro for the current step. Never in combat; never overwrites a macro the player made.
function Card.MakeMacro()
    if A.InCombat() then ns.Slash.Print(L["Not available in combat."]); return end
    local name = writeMacro((Card.MacroBody()))
    if name then ns.Slash.Print(L["Macro %s is set. Drag it to a bar and click it."]:format(name)) end
end

-- With the setting on, keep the CT macro on the current step. Runs on every card refresh, and when the setting
-- turns on. Nothing is written when the body is unchanged, so a refresh after combat is the whole queue.
local failedOnce
function Card.FollowMacro(fresh)
    if not (App.db and ns.addon.db.profile.macroFollow) or A.InCombat() then return end
    if fresh then failedOnce = nil end
    local body, step = Card.MacroBody()
    local ui = App.db.ui
    local before = ui.macroName
    local run = App.Current()
    -- A player's edit lasts one run: a new run, or the setting turning on, takes the macro back.
    local reclaim = fresh or (run and ui.macroRun ~= run.runId)
    local name, changed = writeMacro(body, true, failedOnce, reclaim)
    if name and run then ui.macroRun = run.runId end
    if name and name ~= before then ns.Slash.Print(L["Macro %s is set. Drag it to a bar and click it."]:format(name)) end
    if name == nil then failedOnce = true end
    if changed then App.Log("macro set " .. (step and step.id or "none")) end
end

ns.Start(function()
    local function apply() Card.ApplyPosition(); Card.ApplyAppearance() end
    ns.Settings.onChange = apply
    local db = ns.addon.db
    for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
        db.RegisterCallback(Card, event, apply)
    end
end)
