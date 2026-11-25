-- The Categories window: one row per category with its state in words, its counts and a color, for runs with many
-- categories. It is a second movable window, apart from the card. A click on a row opens the items for that category.
-- Only the player's clicks do anything.
local _, ns = ...
local L = ns.L
local App = ns.App
local A = ns.Adapter
local Card = ns.Card

local Tracker = {}
ns.Tracker = Tracker

local win
local list -- the item list that stands in for a context menu (Tracker.ItemList)
local function closeList() if list then list:Hide() end end
local ROW, MAXROWS, WIDTH = 20, 14, 380
local offset = 0 -- first row shown (a category or a step): the mouse wheel and the page buttons move it when the list is longer than the window
local shownRun -- the run the list was drawn for
local leaving = false -- the game is logging out or reloading: hiding the window then is not the player closing it
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function cfg()
    return (ns.addon and ns.addon.db and ns.addon.db.profile.card) or ns.defaults.profile.card
end

local function text(parent, font, w, justify)
    local f = parent:CreateFontString(nil, "OVERLAY", font)
    f:SetWidth(w); f:SetJustifyH(justify or "LEFT"); f:SetWordWrap(false)
    return f
end

local function place(frame, x, y, anchor)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", anchor or win, "TOPLEFT", x, -y)
end

-- Grow and shrink downward: the top edge stays put, whatever point the window hangs from.
local function setHeight(h)
    local top, left = win:GetTop(), win:GetLeft()
    win:SetHeight(h)
    if type(top) == "number" and type(left) == "number" then
        win:ClearAllPoints(); win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

local function rowFrame(i)
    local r = win.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, win)
    r:SetSize(WIDTH - 24, ROW)
    r:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    r:GetHighlightTexture():SetAlpha(0.35)
    -- The standard plus and minus buttons of Blizzard's collapsible lists open and close the steps of a category.
    r.toggle = CreateFrame("Button", nil, r)
    r.toggle:SetSize(14, 14); r.toggle:SetPoint("LEFT", 0, 0)
    r.toggle:SetScript("OnClick", function() Tracker.ToggleSteps(r.cat) end)
    r.toggle:SetScript("OnEnter", function(self) A.Tooltip(self, self.tip) end)
    r.toggle:SetScript("OnLeave", function() A.TooltipHide() end)
    r.swatch = r:CreateTexture(nil, "ARTWORK"); r.swatch:SetSize(10, 10); r.swatch:SetPoint("LEFT", 16, 0)
    r.label = text(r, "GameFontHighlightSmall", 98)
    r.arrow = r:CreateTexture(nil, "OVERLAY")
    r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow"); r.arrow:SetSize(10, 10); r.arrow:SetRotation(-math.pi / 2)
    r.arrow:SetPoint("RIGHT", -2, 0)
    r.detail = text(r, "GameFontHighlightSmall", 215, "RIGHT")
    r:SetScript("OnClick", function(self) if self.stepData then Tracker.StepClick(self) else Tracker.RowMenu(self) end end)
    r:SetScript("OnEnter", function(self) A.Tooltip(self, self.tip) end)
    r:SetScript("OnLeave", function() A.TooltipHide() end)
    win.rows[i] = r
    return r
end

local function build()
    win = CreateFrame("Frame", "CheckThatCategories", UIParent, "BackdropTemplate")
    win:SetSize(WIDTH, 80)
    win:SetMovable(true); win:EnableMouse(true); win:SetClampedToScreen(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) if not cfg().locked then self:StartMoving() end end)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        cfg().trackerPos = { p, rp, x, y }
    end)
    win:EnableMouseWheel(true)
    win:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta; Tracker.Refresh() end)
    win.texts, win.rows = {}, {}
    win.title = text(win, "GameFontHighlight", 200); place(win.title, 12, 9)
    win.texts[#win.texts + 1] = win.title
    win.title:SetText(L["Categories"])
    -- No overall count in the header: each row says what happened to its steps, and the card's caption has the total.
    win.caption = text(win, "GameFontHighlightSmall", WIDTH - 24); place(win.caption, 12, 28) -- only for "no run"
    win.texts[#win.texts + 1] = win.caption
    win.more = text(win, "GameFontHighlightSmall", WIDTH - 24 - 56)
    win.texts[#win.texts + 1] = win.more
    -- Page buttons beside the mouse wheel: 14 categories a page.
    win.up = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.up:SetSize(26, 20); win.up:SetText("<")
    win.down = CreateFrame("Button", nil, win, "UIPanelButtonTemplate"); win.down:SetSize(26, 20); win.down:SetText(">")
    win.up:SetScript("OnClick", function() offset = offset - MAXROWS; Tracker.Refresh() end)
    win.down:SetScript("OnClick", function() offset = offset + MAXROWS; Tracker.Refresh() end)
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 3, 3)
    close:SetScript("OnClick", function() Tracker.Hide() end)
    win:SetScript("OnShow", function() Tracker.Refresh() end)
    win:SetScript("OnHide", function() closeList(); if not leaving then cfg().trackerOpen = false end end) -- Esc, or the close button
    A.SpecialFrame("CheckThatCategories")
    Tracker.ApplyPosition()
    Tracker.ApplyAppearance()
    win:Hide()
end

function Tracker.ApplyPosition()
    if not win then return end
    local pos = cfg().trackerPos
    win:ClearAllPoints()
    if pos then win:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else win:SetPoint("LEFT", UIParent, "LEFT", 20, 0) end
end

-- Pure black fill at the card's opacity, nothing drawn at zero, text and swatches at the text opacity.
function Tracker.ApplyAppearance()
    if not win then return end
    local c = cfg()
    local bg = (c.backgroundOpacity or 90) / 100
    if bg > 0 then win:SetBackdrop(BACKDROP); win:SetBackdropColor(0, 0, 0, bg); win:SetBackdropBorderColor(0.3, 0.3, 0.3, bg)
    else win:SetBackdrop(nil) end
    local ta = (c.textOpacity or 100) / 100
    for _, f in ipairs(win.texts) do f:SetAlpha(ta) end
    for _, r in ipairs(win.rows) do r.swatch:SetAlpha(ta); r.label:SetAlpha(ta); r.detail:SetAlpha(ta); r.arrow:SetAlpha(ta) end
    if win:IsShown() then Tracker.Refresh() end
end

-- The list that stands in for a context menu where the game has none (or its menu failed): one button per item, nothing runs
-- until the player picks one. Esc closes only this list: it takes the key before UISpecialFrames can close the window.
function Tracker.ItemList(row, items)
    if not list then
        list = CreateFrame("Frame", "CheckThatCategoryList", UIParent, "BackdropTemplate")
        list:SetFrameStrata("DIALOG"); list:SetClampedToScreen(true); list:EnableMouse(true); list:EnableKeyboard(true)
        list.buttons = {}
        list:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then self:SetPropagateKeyboardInput(false); self:Hide() else self:SetPropagateKeyboardInput(true) end
        end)
    end
    local c = cfg()
    local bg = (c.backgroundOpacity or 90) / 100
    if bg > 0 then list:SetBackdrop(BACKDROP); list:SetBackdropColor(0, 0, 0, bg); list:SetBackdropBorderColor(0.3, 0.3, 0.3, bg)
    else list:SetBackdrop(nil) end
    for i, it in ipairs(items) do
        local b = list.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, list, "UIPanelButtonTemplate"); b:SetSize(WIDTH - 40, ROW)
            b:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6 - (i - 1) * ROW)
            list.buttons[i] = b
        end
        b:SetText(it[1])
        b:SetScript("OnClick", function() closeList(); it[2]() end)
        b:Show()
    end
    for i = #items + 1, #list.buttons do list.buttons[i]:Hide() end
    list:SetSize(WIDTH - 28, 12 + #items * ROW)
    list:ClearAllPoints(); list:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
    list:Show()
end

-- The items of one category row.
function Tracker.RowMenu(row)
    local items = Card.CategoryItems(row.cat)
    if (App.RerunCount(ns.Run.FAILED) or 0) > 0 then
        items[#items + 1] = { L["Rerun failed and unverified steps in all categories"], function() Card.AskRerun(ns.Run.FAILED) end }
    end
    if #items == 0 then ns.Slash.Print(L["Nothing to do in %s: it has no open step and no result to rerun."]:format(ns.Slash.Esc(row.cat.title))); return end
    if not A.ContextMenu(row, items) then Tracker.ItemList(row, items) end
end

-- A step's result as a mark and a color: the word is the main cue, so color is never the only one.
local STEP_MARK = {
    pass = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t", fail = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12|t",
    partial = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:12|t", unverified = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:12|t",
}
local STEP_STATE = { pass = "green", fail = "red", partial = "yellow", unverified = "yellow", pending = "blue" }

local expanded, expandedFor = {}, nil -- category ids whose steps show, for the run they were chosen in

-- The flat list the window pages over: a row for each category, then a row for each step of an expanded one.
local function flatten(rows)
    local out = {}
    for _, c in ipairs(rows) do
        out[#out + 1] = { cat = c }
        if expanded[c.id] then
            for _, s in ipairs(App.CategorySteps(c.id)) do out[#out + 1] = { step = s, cat = c } end
        end
    end
    return out
end

function Tracker.ToggleSteps(c)
    expanded[c.id] = not expanded[c.id] or nil
    App.Log(("tracker %s %s"):format(expanded[c.id] and "expand" or "collapse", c.id))
    Tracker.Refresh()
end

-- A click on a step row shows that step. A step that is not offered does nothing.
function Tracker.StepClick(row)
    if not row.stepData.offered then return end
    local ok, err = App.ShowStep(row.stepData.id)
    if not ok then ns.Slash.Print(err); return end
    Card.Refresh()
end

function Tracker.Refresh()
    if not (win and win:IsShown()) then return end
    local cats, overall, sum, run = App.Categories()
    if run and run.runId ~= shownRun then shownRun, offset = run.runId, 0 end -- another run starts at the top
    if run and run ~= expandedFor then expandedFor, expanded = run, {} end -- and collapsed
    for _, r in ipairs(win.rows) do r:Hide() end
    win.more:Hide(); win.up:Hide(); win.down:Hide()
    local ta = (cfg().textOpacity or 100) / 100
    if not cats then
        win.caption:SetText(L["There is no run."]); win.caption:SetTextColor(0.67, 0.67, 0.67); win.caption:Show()
        setHeight(52); return
    end
    win.caption:Hide()
    local rows = flatten(cats)
    local visible = math.min(#rows, MAXROWS)
    offset = math.max(0, math.min(offset, #rows - visible))
    for i = 1, visible do
        local e = rows[i + offset]
        local c, s = e.cat, e.step
        local r = rowFrame(i)
        r.cat, r.stepData = c, s or false -- false, not nil: a row frame is reused for either kind
        place(r, 12, 30 + (i - 1) * ROW)
        r.label:ClearAllPoints(); r.detail:ClearAllPoints()
        if s then
            -- a step: indented under its category, no menu arrow, no expand button
            r.tip = L["%s (%s)"]:format(s.title, s.word) .. (s.offered and ("\n" .. L["Click to show this step."]) or "")
            r.toggle:Hide(); r.arrow:Hide(); r.swatch:Hide()
            r.label:SetPoint("LEFT", 44, 0); r.label:SetWidth(165)
            r.detail:SetPoint("RIGHT", -4, 0); r.detail:SetWidth(120)
            r.label:SetText(s.title)
            r.detail:SetText((STEP_MARK[s.verdict] and (STEP_MARK[s.verdict] .. " ") or "") .. s.word)
            local tc = Card.STATE_TEXT[STEP_STATE[s.verdict] or "grey"]
            r.detail:SetTextColor(tc[1], tc[2], tc[3])
        else
            r.tip = App.CategoryLine(c) .. "\n" .. L["Click for actions."]
            r.toggle.tip = expanded[c.id] and L["Hide the steps of this category."] or L["Show the steps of this category."]
            r.toggle:SetNormalTexture(expanded[c.id] and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
            r.toggle:Show(); r.arrow:Show(); r.swatch:Show()
            local sc = Card.STATE_COLOR[c.state]
            r.swatch:SetColorTexture(sc[1], sc[2], sc[3], 1)
            r.label:SetPoint("LEFT", 32, 0); r.label:SetWidth(98)
            r.detail:SetPoint("RIGHT", -16, 0); r.detail:SetWidth(215)
            r.label:SetText(c.title)
            r.detail:SetText(App.RowDetail(c))
            local tc = Card.STATE_TEXT[c.state]
            r.detail:SetTextColor(tc[1], tc[2], tc[3])
        end
        r.swatch:SetAlpha(ta); r.label:SetAlpha(ta); r.detail:SetAlpha(ta); r.arrow:SetAlpha(ta); r.toggle:SetAlpha(ta)
        r:Show()
    end
    local height = 36 + visible * ROW
    if #rows > visible then
        place(win.more, 12, height - 2)
        win.more:SetText(L["Showing %d to %d of %d. Use the mouse wheel to see more."]:format(offset + 1, offset + visible, #rows))
        win.more:SetTextColor(0.67, 0.67, 0.67); win.more:Show()
        place(win.up, WIDTH - 12 - 56, height - 6); place(win.down, WIDTH - 12 - 28, height - 6)
        win.up:SetEnabled(offset > 0); win.down:SetEnabled(offset + visible < #rows)
        win.up:Show(); win.down:Show()
        height = height + 22
    end
    setHeight(height + 8)
end

function Tracker.Show()
    if not win then build() end
    cfg().trackerOpen = true
    win:Show()
    App.Log("tracker open")
    Tracker.Refresh()
end

function Tracker.Hide()
    cfg().trackerOpen = false
    if win then win:Hide() end
end

-- Called at logout and reload: the window hides with the interface, and that must not read as the player closing it.
function Tracker.Leaving() leaving = true end

function Tracker.Toggle()
    if win and win:IsShown() then Tracker.Hide() else Tracker.Show() end
end

-- The window comes back after a reload if it was open.
ns.Start(function()
    if cfg().trackerOpen then Tracker.Show() end
end)
