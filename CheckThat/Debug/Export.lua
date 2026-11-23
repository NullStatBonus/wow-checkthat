-- The copyable text window (debug report, results string, plan import). One reusable frame.
local _, ns = ...
local L = ns.L

local Export = {}
ns.Export = Export

local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
local box

local function build()
    box = CreateFrame("Frame", "CheckThatTextBox", UIParent, "BackdropTemplate")
    box:SetSize(520, 240); box:SetPoint("CENTER"); box:SetFrameStrata("FULLSCREEN_DIALOG") -- above the card and its protected Run button (DIALOG)
    box:SetBackdrop(BACKDROP); box:SetBackdropColor(0, 0, 0, 0.95); box:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    box:SetMovable(true); box:EnableMouse(true); box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving); box:SetScript("OnDragStop", box.StopMovingOrSizing)
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal"); box.title:SetPoint("TOPLEFT", 10, -8)
    box.title:SetWidth(470); box.title:SetJustifyH("LEFT")
    local close = CreateFrame("Button", nil, box, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)
    local sf = CreateFrame("ScrollFrame", "CheckThatTextScroll", box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, -32); sf:SetPoint("BOTTOMRIGHT", -30, 40)
    box.edit = CreateFrame("EditBox", nil, sf)
    box.edit:SetMultiLine(true); box.edit:SetFontObject("ChatFontNormal"); box.edit:SetWidth(470)
    box.edit:SetAutoFocus(true); sf:SetScrollChild(box.edit)
    box.edit:SetScript("OnEscapePressed", function() box:Hide() end)
    box.edit:SetScript("OnEditFocusGained", function(self) if box.readOnly then self:HighlightText() end end)
    -- Read-only text (report, results string): typing, cuts and deletes revert so the copy is exact.
    box.edit:SetScript("OnTextChanged", function(self, user)
        if user and box.readOnly then self:SetText(box.value or ""); self:HighlightText() end
    end)
    box.ok = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    box.ok:SetSize(90, 22); box.ok:SetPoint("BOTTOMRIGHT", -10, 10)
    box.ok:SetScript("OnClick", function()
        local fn, text = box.onAccept, box.edit:GetText()
        box:Hide()
        if fn then fn(text) end
    end)
    box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); box.hint:SetPoint("BOTTOMLEFT", 10, 16)

    -- A small dropdown (plain buttons, no template): a "Recent" button opens a list of choices.
    box.recent = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    box.recent:SetSize(170, 22); box.recent:SetPoint("BOTTOMLEFT", 10, 10)
    box.menu = CreateFrame("Frame", nil, box, "BackdropTemplate")
    box.menu:SetBackdrop(BACKDROP); box.menu:SetBackdropColor(0, 0, 0, 1); box.menu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    box.menu:SetFrameLevel((tonumber(box:GetFrameLevel()) or 1) + 10); box.menu:SetWidth(300); box.menu:Hide()
    box.menu.items = {}
    box.recent:SetScript("OnClick", function() if box.menu:IsShown() then box.menu:Hide() else Export.OpenMenu() end end)
    box:HookScript("OnHide", function() box.menu:Hide() end)
end

-- Fill and show the choices list above the button.
function Export.OpenMenu()
    local menu, choices = box.menu, box.choices or {}
    for _, b in ipairs(menu.items) do b:Hide() end
    for i, ch in ipairs(choices) do
        local b = menu.items[i]
        if not b then
            b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate"); b:SetSize(288, 22)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 24); menu.items[i] = b
        end
        b:SetText(ch.text)
        b:SetScript("OnClick", function() menu:Hide(); local fn = box.onChoose; if fn then box:Hide(); fn(ch.id) end end)
        b:Show()
    end
    menu:SetHeight(12 + math.max(1, #choices) * 24)
    menu:ClearAllPoints(); menu:SetPoint("BOTTOMLEFT", box.recent, "TOPLEFT", 0, 2)
    menu:Show()
end

-- Read-only text, selected for Ctrl+A / Ctrl+C.
function Export.Show(title, text)
    Export.Prompt(title, text, nil, L["Close"], L["Press Ctrl+C to copy."], true)
end

-- Editable text. onAccept(text) runs when the player presses the button.
-- opts.choices = { { id, text }, ... } adds a "Recent plans" dropdown; opts.onChoose(id) runs on a pick.
function Export.Prompt(title, content, onAccept, label, hint, readOnly, opts)
    if not box then build() end
    box.choices, box.onChoose = opts and opts.choices, opts and opts.onChoose
    box.menu:Hide()
    if box.choices then
        box.recent:SetText(#box.choices > 0 and L["Recent plans"] or L["No recent plans"]); box.recent:Show()
        if #box.choices == 0 then box.recent:Disable() else box.recent:Enable() end
        box.hint:ClearAllPoints(); box.hint:SetPoint("BOTTOMLEFT", 190, 16)
    else
        box.recent:Hide(); box.hint:ClearAllPoints(); box.hint:SetPoint("BOTTOMLEFT", 10, 16)
    end
    box.readOnly, box.value = readOnly and true or false, content or ""
    box.title:SetText(title); box.onAccept = onAccept
    box.ok:SetText(label or L["Close"]); box.hint:SetText(hint or "")
    box.edit:SetText(content or ""); box:Show(); box.edit:HighlightText(); box.edit:SetFocus()
end
