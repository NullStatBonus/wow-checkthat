-- The category picker: a checkbox per category of the plan on the card's start screen, for plans with more categories
-- than the card lists inline. It pages like the Categories window and changes the same picked set as the Home page.
-- Only the player's clicks do anything.
local _, ns = ...
local L = ns.L
local App = ns.App
local A = ns.Adapter

local Picker = {}
ns.Picker = Picker

local win
local addon -- the plan being picked
local offset = 0
local total = 0 -- categories listed
local ROW, MAXROWS, WIDTH = 24, 14, 380
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function cfg()
    return (ns.addon and ns.addon.db and ns.addon.db.profile.card) or ns.defaults.profile.card
end

local function text(parent, font, w)
    local f = parent:CreateFontString(nil, "OVERLAY", font)
    f:SetWidth(w); f:SetJustifyH("LEFT"); f:SetWordWrap(false)
    return f
end

local function place(frame, x, y)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", win, "TOPLEFT", x, -y)
end

local function rowFrame(i)
    local r = win.rows[i]
    if r then return r end
    r = {}
    r.check = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    r.check:SetSize(24, 24)
    r.check:SetScript("OnClick", function(self)
        App.SetPick(addon, self.cat, self:GetChecked() and true or false)
        if ns.Card then ns.Card.Refresh() else Picker.Refresh() end
        if ns.Options and ns.Options.Notify then ns.Options.Notify() end -- Home shows the same boxes
    end)
    r.label = text(win, "GameFontHighlight", WIDTH - 60)
    win.rows[i] = r
    return r
end

local function build()
    win = CreateFrame("Frame", "CheckThatPicker", UIParent, "BackdropTemplate")
    win:SetSize(WIDTH, 80)
    win:SetMovable(true); win:EnableMouse(true); win:SetClampedToScreen(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) if not cfg().locked then self:StartMoving() end end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:EnableMouseWheel(true)
    win:SetScript("OnMouseWheel", function(_, delta) offset = math.max(0, math.min(offset - delta, total - MAXROWS)); Picker.Refresh() end)
    win.texts, win.rows = {}, {}
    win.title = text(win, "GameFontHighlight", 200); place(win.title, 12, 9)
    win.title:SetText(L["Choose categories"])
    win.more = text(win, "GameFontHighlightSmall", WIDTH - 24 - 56)
    win.none = text(win, "GameFontHighlightSmall", WIDTH - 24)
    win.texts = { win.title, win.more, win.none }
    win.up = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.up:SetSize(26, 20); win.up:SetText("<")
    win.down = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.down:SetSize(26, 20); win.down:SetText(">")
    win.up:SetScript("OnClick", function() offset = offset - MAXROWS; Picker.Refresh() end)
    win.down:SetScript("OnClick", function() offset = offset + MAXROWS; Picker.Refresh() end)
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 3, 3)
    close:SetScript("OnClick", function() Picker.Hide() end)
    win:SetScript("OnShow", function() Picker.Refresh() end)
    A.SpecialFrame("CheckThatPicker")
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:Hide()
end

function Picker.Appearance()
    if not win then return end
    local c = cfg()
    local bg = (c.backgroundOpacity or 90) / 100
    if bg > 0 then win:SetBackdrop(BACKDROP); win:SetBackdropColor(0, 0, 0, bg); win:SetBackdropBorderColor(0.3, 0.3, 0.3, bg)
    else win:SetBackdrop(nil) end
    local ta = (c.textOpacity or 100) / 100
    for _, f in ipairs(win.texts) do f:SetAlpha(ta) end
    for _, r in ipairs(win.rows) do r.label:SetAlpha(ta) end
end

-- The plan the window lists. A new plan starts at the top.
function Picker.Follow(id)
    if id ~= addon then addon, offset = id, 0 end
    Picker.Refresh()
end

function Picker.Show(id)
    if not win then build() end
    offset = 0
    Picker.Follow(id)
    win:Show()
    Picker.Refresh()
end

function Picker.Hide() if win then win:Hide() end end

function Picker.Refresh()
    if not (win and win:IsShown()) then return end
    local list = addon and App.db and App.Picks(addon) or {}
    if #list <= (ns.Card and ns.Card.MAX_SEGMENTS or 8) then win:Hide(); return end -- nothing to choose, or the card lists them
    for _, r in ipairs(win.rows) do r.check:Hide(); r.label:Hide() end
    win.more:Hide(); win.up:Hide(); win.down:Hide(); win.none:Hide()
    total = #list
    local visible = math.min(#list - offset, MAXROWS) -- a short last page is fine: the page buttons keep their 14-row steps
    offset = math.max(0, math.min(offset, #list - 1))
    visible = math.min(#list - offset, MAXROWS)
    local any = false
    for _, c in ipairs(list) do if c.picked and c.steps > 0 then any = true; break end end
    for i = 1, visible do
        local c, r = list[i + offset], rowFrame(i)
        r.check.cat = c.id
        r.check:SetChecked(c.picked)
        place(r.check, 10, 30 + (i - 1) * ROW); place(r.label, 38, 35 + (i - 1) * ROW)
        r.label:SetText(c.steps == 1 and L["%s: 1 step"]:format(c.title) or L["%s: %d steps"]:format(c.title, c.steps))
        r.check:Show(); r.label:Show()
    end
    local height = 34 + visible * ROW
    if not any then
        place(win.none, 12, height); win.none:SetText(L["Select at least one category."]); win.none:SetTextColor(1, 0.82, 0.2); win.none:Show()
        height = height + 18
    end
    if #list > visible or offset > 0 then
        place(win.more, 12, height + 2)
        win.more:SetText(L["Showing %d to %d of %d. Use the mouse wheel to see more."]:format(offset + 1, offset + visible, #list))
        win.more:SetTextColor(0.67, 0.67, 0.67); win.more:Show()
        place(win.up, WIDTH - 12 - 56, height - 2); place(win.down, WIDTH - 12 - 28, height - 2)
        win.up:SetEnabled(offset > 0); win.down:SetEnabled(offset + visible < #list)
        win.up:Show(); win.down:Show()
        height = height + 22
    end
    win:SetHeight(height + 10)
    Picker.Appearance()
end
