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
local ROW, MAXROWS, WIDTH = 20, 14, 380
local offset = 0 -- first category shown: the mouse wheel and the page buttons move it when the list is longer than the window
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

local function rowFrame(i)
    local r = win.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, win)
    r:SetSize(WIDTH - 24, ROW)
    r:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    r:GetHighlightTexture():SetAlpha(0.35)
    r.swatch = r:CreateTexture(nil, "ARTWORK"); r.swatch:SetSize(10, 10); r.swatch:SetPoint("LEFT", 2, 0)
    r.label = text(r, "GameFontHighlightSmall", 110); r.label:SetPoint("LEFT", 18, 0)
    r.arrow = r:CreateTexture(nil, "OVERLAY")
    r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow"); r.arrow:SetSize(10, 10); r.arrow:SetRotation(-math.pi / 2)
    r.arrow:SetPoint("RIGHT", -2, 0)
    r.detail = text(r, "GameFontHighlightSmall", 215, "RIGHT"); r.detail:SetPoint("RIGHT", -16, 0)
    r:SetScript("OnClick", function(self) Tracker.RowMenu(self) end)
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
    win:SetScript("OnHide", function() if not leaving then cfg().trackerOpen = false end end) -- Esc, or the close button
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

-- The items of one category row. Where the game has no menu, the main item runs at once.
function Tracker.RowMenu(row)
    local items = Card.CategoryItems(row.cat)
    if (App.RerunCount(ns.Run.FAILED) or 0) > 0 then
        items[#items + 1] = { L["Rerun failed and unverified steps in all categories"], function() Card.AskRerun(ns.Run.FAILED) end }
    end
    if #items == 0 then ns.Slash.Print(L["Nothing to do in %s: it has no open step and no result to rerun."]:format(ns.Slash.Esc(row.cat.title))); return end
    if not A.ContextMenu(row, items) then items[1][2]() end
end

function Tracker.Refresh()
    if not (win and win:IsShown()) then return end
    local rows, overall, sum, run = App.Categories()
    if run and run.runId ~= shownRun then shownRun, offset = run.runId, 0 end -- another run starts at the top of the list
    for _, r in ipairs(win.rows) do r:Hide() end
    win.more:Hide(); win.up:Hide(); win.down:Hide()
    local ta = (cfg().textOpacity or 100) / 100
    if not rows then
        win.caption:SetText(L["There is no run."]); win.caption:SetTextColor(0.67, 0.67, 0.67); win.caption:Show()
        win:SetHeight(52); return
    end
    win.caption:Hide()
    local visible = math.min(#rows, MAXROWS)
    offset = math.max(0, math.min(offset, #rows - visible))
    for i = 1, visible do
        local c = rows[i + offset]
        local r = rowFrame(i)
        r.cat, r.tip = c, App.CategoryLine(c) .. "\n" .. L["Click for actions."]
        place(r, 12, 30 + (i - 1) * ROW)
        local sc = Card.STATE_COLOR[c.state]
        r.swatch:SetColorTexture(sc[1], sc[2], sc[3], 1); r.swatch:SetAlpha(ta)
        r.label:SetText(c.title)
        r.detail:SetText(App.RowDetail(c))
        local tc = Card.STATE_TEXT[c.state]
        r.detail:SetTextColor(tc[1], tc[2], tc[3])
        r.label:SetAlpha(ta); r.detail:SetAlpha(ta); r.arrow:SetAlpha(ta)
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
    win:SetHeight(height + 8)
end

function Tracker.Show()
    if not win then build() end
    cfg().trackerOpen = true
    win:Show()
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
