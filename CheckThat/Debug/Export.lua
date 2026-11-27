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
        -- The button's text is centred and not clipped: hold it to one line inside the button, cut with "..." (#246).
        local fs = b.GetFontString and b:GetFontString()
        if fs then fs:SetWidth(272); fs:SetWordWrap(false) end
        b:SetScript("OnClick", function() menu:Hide(); local fn = box.onChoose; if fn then box:Hide(); fn(ch.id) end end)
        b:Show()
    end
    menu:SetHeight(12 + math.max(1, #choices) * 24)
    menu:ClearAllPoints(); menu:SetPoint("BOTTOMLEFT", box.recent, "TOPLEFT", 0, 2)
    menu:Show()
end

-- Read-only text, selected for Ctrl+A / Ctrl+C, in the standard AceGUI window.
-- It falls back to the plain text window when AceGUI is missing.
local window
local function aceShow(title, text, note)
    local gui = LibStub and LibStub("AceGUI-3.0", true)
    if not (gui and gui.Create) then return false end
    if window then gui:Release(window); window = nil end
    local w = gui:Create("Frame")
    window = w
    w:SetTitle(title)
    local press = L["Press Ctrl+A to select everything, then Ctrl+C to copy."]
    w:SetStatusText(note and (note .. " " .. press) or press)
    w:SetLayout("Fill")
    w:SetCallback("OnClose", function(f) gui:Release(f); if window == f then window = nil end end)
    local edit = gui:Create("MultiLineEditBox")
    edit:SetLabel("")
    edit:DisableButton(true)
    edit:SetText(text)
    edit:SetCallback("OnTextChanged", function(b) b:SetText(text) end)
    w:AddChild(edit)
    edit:SetFocus()
    edit:HighlightText()
    return true
end

-- note: one sentence before the copy hint, such as what the text includes.
function Export.Show(title, text, note)
    local ok, shown = pcall(aceShow, title, text or "", note)
    if ok and shown then if box then box:Hide() end return end
    if window then pcall(function() window:Release() end); window = nil end
    local press = L["Press Ctrl+C to copy."]
    Export.Prompt(title, text, nil, L["Close"], note and (note .. " " .. press) or press, true)
end

-- The editable import window in the same AceGUI frame: a "Choose a plan" dropdown above a text box with the button.
local function aceImport(title, content, onAccept, label, hint, opts)
    local gui = LibStub and LibStub("AceGUI-3.0", true)
    if not (gui and gui.Create) then return false end
    if window then gui:Release(window); window = nil end
    local w = gui:Create("Frame")
    window = w
    local function close() if window == w then window = nil end gui:Release(w) end
    w:SetTitle(title)
    w:SetStatusText(hint or "")
    w:SetLayout("Flow")
    w:SetCallback("OnClose", function() if window == w then window = nil end gui:Release(w) end)
    local choices = opts and opts.choices
    if choices then
        local dd = gui:Create("Dropdown")
        local values, order = {}, {}
        for i, ch in ipairs(choices) do values[ch.id] = ch.text; order[i] = ch.id end
        dd:SetLabel(#choices > 0 and L["Choose a plan"] or L["No recent plans"])
        dd:SetList(values, order)
        dd:SetDisabled(#choices == 0)
        dd:SetFullWidth(true)
        dd:SetCallback("OnValueChanged", function(_, _, key) close(); if opts.onChoose then opts.onChoose(key) end end)
        w:AddChild(dd)
    end
    local edit = gui:Create("MultiLineEditBox")
    edit:SetLabel("")
    edit:SetNumLines(12)
    edit:SetFullWidth(true)
    edit:SetButtonText(label or L["Import"])
    edit:SetText(content or "")
    edit:SetCallback("OnEnterPressed", function(_, _, text) close(); onAccept(text) end)
    w:AddChild(edit)
    edit:SetFocus()
    return true
end

-- Editable text. onAccept(text) runs when the player presses the button.
-- opts.choices = { { id, text }, ... } adds a "Choose a plan" dropdown; opts.onChoose(id) runs on a pick.
function Export.Prompt(title, content, onAccept, label, hint, readOnly, opts)
    if onAccept and not readOnly then
        local ok, shown = pcall(aceImport, title, content, onAccept, label, hint, opts)
        if ok and shown then if box then box:Hide() end return end
        if ns.App and ns.App.Log then ns.App.Log("import window: plain window, AceGUI " .. (ok and "missing" or "failed: " .. tostring(shown))) end
        if window then pcall(function() window:Release() end); window = nil end
    end
    if not box then build() end
    box.choices, box.onChoose = opts and opts.choices or false, opts and opts.onChoose or false
    box.menu:Hide()
    if box.choices then
        box.recent:SetText(#box.choices > 0 and L["Choose a plan"] or L["No recent plans"]); box.recent:Show()
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
