-- The checklist card: one step at a time, copy boxes, the secure Run button, Pass / Fail / Skip / Undo.
-- Only the player's clicks do anything. Appearance comes from the profile (Core/Settings.lua).
local _, ns = ...
local L = ns.L
local App = ns.App
local Card = {}
ns.Card = Card

local card, text
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
    if not card or A.InCombat() then return end
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
end

local INNER = 356
local GREY, BODY = { 0.67, 0.67, 0.67 }, { 0.87, 0.87, 0.87 }
local AMBER, GREEN, RED = { 1, 0.67, 0 }, { 0.6, 1, 0.6 }, { 1, 0.4, 0.4 }

local function fs(font, color, width, justify)
    local f = card:CreateFontString(nil, "OVERLAY", font)
    if color then f:SetTextColor(color[1], color[2], color[3]) end
    if width then f:SetWidth(width) end
    f:SetJustifyH(justify or "LEFT"); f:SetJustifyV("TOP")
    card.texts[#card.texts + 1] = f
    return f
end

local function place(frame, x, y, anchor)
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", anchor or card, "TOPLEFT", x, -y)
end

local function build()
    card = CreateFrame("Frame", "TestThatCard", UIParent, "BackdropTemplate")
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
    card.ticking = false

    -- Header: where we are, and the controls that always stay in the same place.
    card.head = fs("GameFontHighlightSmall", GREY, 120); card.head:SetPoint("TOPLEFT", 12, -9)
    card.step = fs("GameFontHighlightSmall", GREY, 70, "RIGHT"); card.step:SetPoint("TOPRIGHT", -126, -9)
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

    card.title = fs("GameFontHighlightLarge", { 1, 1, 1 }, INNER)
    card.context = fs("GameFontHighlightSmall", GREY, INNER)
    card.evidence = fs("GameFontHighlight", AMBER, INNER)
    card.hint = fs("GameFontHighlightSmall", GREY, INNER)
    card.noteLabel = fs("GameFontHighlightSmall", GREY, 46)
    card.noteLabel:SetText(L["Note"])
    card.tally = fs("GameFontHighlight", BODY, INNER)
    card.reloadedNote = fs("GameFontHighlight", GREEN, INNER)
    card.banner = fs("GameFontHighlightSmall", GREY, INNER)
    card.checks = fs("GameFontHighlight", BODY, INNER)
    card.recorded = fs("GameFontHighlight", BODY, INNER)
    card.redo = makeButton(card, L["Redo this step"], 120); card.redo:SetHeight(24)
    card.redo:SetPoint("BOTTOMLEFT", 12, 12)
    card.redo:SetScript("OnClick", function() App.Begin(); Card.Refresh() end)

    card.copies = {}
    for i = 1, 4 do card.copies[i] = copyBox(card); card.copies[i]:SetWidth(190) end
    -- The secure button is its own top-level frame, so it never makes the card a protected parent:
    -- the card can move, resize and hide in combat. It is only re-pointed and shown out of combat.
    card.secure = CreateFrame("Button", "TestThatSecureButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    card.secure:SetSize(56, 24); card.secure:SetText(L["Run"])
    card.secure:SetFrameStrata("DIALOG")
    card.secure:SetAttribute("type", "macro")
    card.secure:SetAttribute("useOnKeyDown", false)
    card.secure:RegisterForClicks("AnyUp")
    card.secure:Hide()
    card:HookScript("OnHide", function() if not A.InCombat() then card.secure:Hide() end end)
    card:HookScript("OnShow", function() Card.Refresh() end)

    card.note = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
    card.note:SetAutoFocus(false); card.note:SetHeight(20); card.note:SetWidth(296); card.note:SetFontObject("ChatFontNormal")
    card.note:SetMaxLetters(200)
    card.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    card.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Pinned verdict row: fixed positions, native buttons.
    -- Pass, Partial (mostly works), Fail, Skip: one row, fixed places; Reload (when asked for) and Undo at the right.
    card.pass = makeButton(card, L["Pass"], 56); card.partial = makeButton(card, L["Partial"], 56)
    card.fail = makeButton(card, L["Fail"], 56); card.skip = makeButton(card, L["Skip"], 56)
    card.undo = makeButton(card, L["Undo"], 48)
    for _, b in ipairs({ card.pass, card.partial, card.fail, card.skip, card.undo }) do b:SetHeight(24) end
    card.pass:SetPoint("BOTTOMLEFT", 12, 12); card.partial:SetPoint("LEFT", card.pass, "RIGHT", 4, 0)
    card.fail:SetPoint("LEFT", card.partial, "RIGHT", 4, 0); card.skip:SetPoint("LEFT", card.fail, "RIGHT", 4, 0)
    card.undo:SetPoint("BOTTOMRIGHT", -12, 12)
    for k, v in pairs({ pass = "pass", partial = "partial", fail = "fail", skip = "skip" }) do
        card[k]:SetScript("OnClick", function()
            -- The result is recorded first; a drawing error afterwards is logged, never allowed to look like a stuck step.
            local note = card.note:GetText()
            if note == "" then note = nil end
            pcall(function() card.note:SetText(""); card.note:ClearFocus() end)
            local _, _, step = App.Verdict(v, note)
            local ok, err = pcall(function() Card.AfterVerdict(step); Card.Refresh() end)
            if not ok and ns.Log then ns.Log.Failure("card", "after " .. v .. ": " .. tostring(err)) end
        end)
    end
    card.undo:SetScript("OnClick", function() App.Undo(); Card.Refresh() end)

    card.reload = makeButton(card, L["Reload"], 66); card.reload:SetHeight(24)
    card.reload:SetScript("OnClick", function() App.Log("reload by player"); App.db.ui.shareReload = nil; A.Reload() end)
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
        local run, err = App.Start(App.db.ui.pendingStart or App.db.ui.lastImport)
        if not run then ns.Slash.Print(err) end
        Card.Refresh()
    end)
    card.importAgain = makeButton(card, L["Import a plan"], 112); card.importAgain:SetHeight(24)
    card.importAgain:SetPoint("LEFT", card.start, "RIGHT", 6, 0)
    card.importAgain:SetScript("OnClick", Card.ImportPrompt)
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

local function setMacro(step, plan)
    local body = App.MacroText(step, plan)
    if A.InCombat() then card.pendingMacro = true; card.secure:SetAlpha(0.4); return end -- stale until combat ends
    card.pendingMacro = nil
    card.secure:SetAlpha(1)
    if body then card.secure:SetAttribute("macrotext", body); card.secure:Show() else card.secure:SetAttribute("macrotext", ""); card.secure:Hide() end
end

-- A plan can ask for evidence to be shared at a point: a reload (logs reach saved variables) or the export string.
function Card.AfterVerdict(step)
    if not step then return end
    if step.share == "export" then Card.ExportNow()
    elseif step.share == "reload" then
        ns.Slash.Print(L["This plan asks for a reload now so the log reaches the saved file. Press Reload on the card."])
        App.db.ui.shareReload = true
    end
end

function Card.ExportNow()
    local s, err = App.Export()
    if s then ns.Export.Show(L["Results string. Share it with Claude."], s) else ns.Slash.Print(err) end
end

function Card.ImportPrompt()
    local function choose(digest)
        local plan, err = App.UseRecent(digest)
        if plan then
            ns.Slash.Print(L["Using %s."]:format(plan.title))
            Card.Show()
            if ns.Options and ns.Options.Notify then ns.Options.Notify() end
            Card.Refresh()
        else ns.Slash.Print(err) end
    end
    ns.Export.Prompt(L["Paste a plan string (it starts with !WTT1!), or pick a recent plan"], "", function(str)
        local plan, err = App.ImportPlan(str)
        if plan then
            ns.Slash.Print(L["Imported %s."]:format(plan.title))
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
    for _, k in ipairs({ "pass", "partial", "fail", "skip", "undo", "note", "start", "importAgain", "reload", "exportBtn", "noteLabel", "evidence", "hint", "tally", "context", "title", "reloadedNote", "resume", "banner", "checks", "recorded", "redo", "prevBtn", "nextBtn", "mainBtn" }) do card[k]:Hide() end
    for _, r in ipairs(card.rows) do r.label:Hide(); r.body:Hide() end
    card.barBack:Hide(); card.barFill:Hide()
    if not A.InCombat() then card.secure:Hide() end
end

local function setText(f, str, color)
    f:SetText(str or "")
    if color then f:SetTextColor(color[1], color[2], color[3]) end
    f:Show()
end

function Card.Refresh()
    if not card then return end
    local run, ctx, step = App.Current()
    hideAll()
    local collapsed = cfg().collapsed
    local mini = collapsed and run
    card:SetWidth(mini and 280 or 380)
    local inner = mini and 256 or INNER
    card.title:SetWidth(inner); card.barBack:SetWidth(inner)
    card.collapse:SetText(collapsed and "+" or "-")
    card.head:SetText(L["TestThat / Run"])
    card.step:SetText("")
    local pendingAddon = App.db.ui.pendingStart
    if not run or (pendingAddon and App.db.plans[pendingAddon]) then
        -- A plan is waiting to start (just imported or picked): it takes focus, even after a finished run.
        local rec = (pendingAddon or App.db.ui.lastImport) and App.db.plans[pendingAddon or App.db.ui.lastImport]
        place(card.title, 12, 36); setText(card.title, L["TestThat"])
        local y = 36 + card.title:GetStringHeight() + 8
        local msg
        if rec then
            local steps = 0
            for _, s in ipairs(rec.plan.sections) do steps = steps + #s.steps end
            msg = L["Plan ready: %s (%d steps). Select Start run."]:format(rec.plan.title, steps)
            card.start:Show()
        else msg = L["No plan yet. Select Import a plan and paste a plan string."] end
        place(card.context, 12, y); setText(card.context, msg, BODY)
        y = y + card.context:GetStringHeight() + 12
        card.importAgain:Show()
        if run and step then card.resume:Show() end -- an unfinished run can still be resumed
        card:SetHeight(y + 36); return
    end
    local total = #run.order
    local c = ns.Run.Counts(run)
    local resolved = total - (c.pending or 0)
    card.barBack:Show(); card.barFill:Show()
    card.barFill:SetWidth(math.max(1, inner * (total > 0 and resolved / total or 0)))
    if collapsed then
        card.step:SetText(("%d/%d"):format(math.min(resolved + 1, total), total))
        place(card.title, 12, 32); setText(card.title, step and step.title or L["Run complete"])
        card:SetHeight(40 + math.min(card.title:GetStringHeight(), 36)); return
    end
    card.step:SetText(step and L["Step %d/%d"]:format(run.current, total) or ("%d/%d"):format(total, total))
    if not step then
        -- Results and handoff.
        place(card.title, 12, 36); setText(card.title, L["Run complete"])
        local y = 36 + card.title:GetStringHeight() + 6
        place(card.tally, 12, y); setText(card.tally, L["%d passed   %d partial   %d failed   %d skipped"]:format(c.pass, c.partial, c.fail, c.skip), BODY)
        y = y + card.tally:GetStringHeight() + 8
        place(card.context, 12, y)
        setText(card.context, L["Export results to share this run. The game saves the evidence to disk when you reload or log out."] .. "\n" .. (ctx.plan.handoff or ""), GREY)
        y = y + card.context:GetStringHeight() + 12
        card.prevBtn:Show()
        card.exportBtn:ClearAllPoints(); card.exportBtn:SetPoint("BOTTOMLEFT", 12, 12); card.exportBtn:Show()
        card.mainBtn:ClearAllPoints(); card.mainBtn:SetPoint("LEFT", card.exportBtn, "RIGHT", 6, 0); card.mainBtn:Show()
        card.undo:Show()
        card:SetHeight(y + 36); return
    end
    local rec0 = run.steps[step.id]
    local resolved = rec0.verdict ~= "pending" and rec0.verdict ~= "unverified"
    if not resolved then App.Begin() end -- arm evidence before the tester acts
    local lastA = rec0.attempts[#rec0.attempts]
    local open = lastA and not lastA.verdict and lastA or nil
    local viewing = resolved and not open -- a finished step is read-only until Redo
    local reloaded = open and open.reloaded
    local required, hasExtra = {}, false
    for _, a in ipairs(step.assertions or {}) do
        if a.diagnostic then hasExtra = true else required[#required + 1] = a end
    end
    for _, v in ipairs(step.verify or {}) do if v == "reviewer" then hasExtra = true end end
    card.prevBtn:Show(); card.nextBtn:Show()
    local y = 36
    place(card.title, 12, y); setText(card.title, step.title)
    y = y + card.title:GetStringHeight() + 6
    -- Who checks this step: unmissable, right under the title.
    place(card.banner, 12, y)
    if #required > 0 then
        setText(card.banner, L["|cff66ff66TESTTHAT CHECKS THIS STEP.|r It ticks below when it sees your action."], GREY)
    elseif hasExtra then
        setText(card.banner, L["|cffffd100YOU CONFIRM THIS STEP.|r TestThat records extra detail for the reviewer."], GREY)
    else
        setText(card.banner, L["|cffffd100YOU CONFIRM THIS STEP.|r TestThat cannot see it."], GREY)
    end
    y = y + card.banner:GetStringHeight() + 8
    if reloaded then
        place(card.reloadedNote, 12, y); setText(card.reloadedNote, L["Reloaded. Check the result now, then record it."], GREEN)
        y = y + card.reloadedNote:GetStringHeight() + 8
    end
    local extra = {}
    if ctx.plan.preamble and App.AtStart(run) then extra[#extra + 1] = L["Before you start: %s"]:format(ctx.plan.preamble:sub(1, 300)) end
    local intro = App.SectionIntro(run, ctx, step.id)
    if intro then extra[#extra + 1] = L["This section: %s"]:format(intro:sub(1, 240)) end
    local blocked = ns.Run.Blocked(ctx, step)
    if #blocked > 0 then extra[#extra + 1] = L["Blocked: %s"]:format(table.concat(blocked, "; ")) end
    if #extra > 0 then
        place(card.context, 12, y); setText(card.context, table.concat(extra, "\n"), GREY)
        y = y + card.context:GetStringHeight() + 8
    end
    local rows = {}
    if step.setup then rows[#rows + 1] = { L["Setup"], step.setup } end
    rows[#rows + 1] = { L["Do"], step.action.text or L["Use the command below."] }
    rows[#rows + 1] = { L["Expect"], step.expect }
    local copies = App.Copyables(step, ctx.plan)
    local firstCopy
    for i, r in ipairs(rows) do
        local row = card.rows[i]
        place(row.label, 12, y + 2); setText(row.label, r[1], GREY)
        place(row.body, 62, y); setText(row.body, r[2], BODY)
        y = y + row.body:GetStringHeight() + 6
        if r[1] == L["Do"] and not viewing then
            for k, e in ipairs(card.copies) do
                if copies[k] then
                    e:Set(copies[k]); place(e, 66, y); e:Show()
                    firstCopy = firstCopy or e
                    y = y + 26
                end
            end
        end
        y = y + 4
    end
    -- Live checks: each required check ticks as TestThat sees it.
    card.checkStep = nil
    if #required > 0 and open then
        card.checkStep = step.id
        place(card.checks, 12, y); card.checks:Show()
        local items = ns.Run.Preview(run, ctx, step.id)
        card.checks:SetText(Card.ChecksText(items, true)) -- measure the longest state so a green list never grows into the buttons
        y = y + card.checks:GetStringHeight() + 14
        card.checks:SetText(Card.ChecksText(items))
    end
    if viewing then
        -- A finished step: show what was recorded, offer Redo. Nothing here changes the result.
        local word = ({ pass = L["Pass"], partial = L["Partial"], fail = L["Fail"], skip = L["Skip"] })[rec0.verdict] or rec0.verdict
        local last = lastA
        place(card.recorded, 12, y)
        setText(card.recorded, L["Recorded: %s"]:format(word) .. ((last and last.note) and ("  -  " .. last.note) or ""), BODY)
        y = y + card.recorded:GetStringHeight() + 12
        card.redo:Show()
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
    local hint = {}
    if step.screenshot then hint[#hint + 1] = L["Press Print Screen while the result is on screen."] end
    if step.reload == "after_action" and not reloaded then hint[#hint + 1] = L["Press Reload when done. This step resumes after."] end
    if App.db.ui.shareReload then hint[#hint + 1] = L["Reload now so Claude can read the log."] end
    if #hint > 0 then place(card.hint, 12, y); setText(card.hint, table.concat(hint, " "), GREY); y = y + card.hint:GetStringHeight() + 6 end
    y = y + 6
    card.noteLabel:Show(); place(card.noteLabel, 12, y + 3)
    place(card.note, 62, y - 1); card.note:Show()
    y = y + 34
    for _, k in ipairs({ "pass", "partial", "fail", "skip", "undo" }) do card[k]:Show() end
    -- The secure button sits beside the first command; Reload sits in the verdict row only when asked for.
    card.secureAnchor = firstCopy or false
    setMacro(step, ctx.plan)
    Card.PlaceSecure()
    A.After(0.2, Card.PlaceSecure) -- layout settles a moment after the first show
    local needReload = (step.reload == "after_action" and not reloaded) or step.action.kind == "reload" or App.db.ui.shareReload == true
    card.reload:ClearAllPoints(); card.reload:SetPoint("RIGHT", card.undo, "LEFT", -6, 0)
    card.reload:SetShown(needReload)
    card:SetHeight(y + 40)
end

-- < and >: move the viewed step. Logged, and a drawing error is recorded instead of looking like a dead button.
function Card.Go(delta)
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
function Card.ChecksText(items, reserve)
    local lines, allMet = {}, #items > 0
    for _, it in ipairs(items) do
        local a = it.assertion
        local label = it.label
        if not label then
            if a.kind == "log-sequence" then label = L["Matching lines in the debug log, in order"]
            elseif a.kind == "state" then label = L["The game state matches"]
            else label = L["A matching line in the debug log"] end
        end
        if it.state ~= "met" then allMet = false end
        local tail = it.state == "later" and ("  " .. L["(checked when you press Pass)"]) or ""
        lines[#lines + 1] = ICON[it.state] .. " " .. TINT[it.state] .. label .. tail .. "|r"
    end
    if allMet or reserve then lines[#lines + 1] = L["|cff66ff66All checks detected. Press Pass.|r"] end
    return table.concat(lines, "\n")
end

-- Re-reads the live checks of the current step; the loop in Show calls it twice a second.
function Card.UpdateChecks()
    if not (card and card:IsShown() and card.checkStep) then return end
    local run, ctx, step = App.Current()
    if run and step and step.id == card.checkStep then
        card.checks:SetText(Card.ChecksText(ns.Run.Preview(run, ctx, step.id)))
    end
end

local function tick()
    if not (card and card:IsShown()) then if card then card.ticking = false end return end
    Card.UpdateChecks()
    A.After(0.5, tick)
end

function Card.Show()
    if not card then build() end
    card:Show(); Card.Refresh()
    if not card.ticking then card.ticking = true; A.After(0.5, tick) end
end
function Card.Toggle() if card and card:IsShown() then card:Hide() else Card.Show() end end

-- Create or update the macro for the current step. Never in combat; never overwrites a macro the player made.
function Card.MakeMacro()
    if A.InCombat() then ns.Slash.Print(L["Not available in combat."]); return end
    local _, ctx, step = App.Current()
    local body = step and App.MacroText(step, ctx.plan) or "/wtt status"
    local ui = App.db.ui
    local name, idx = ui.macroName, nil
    if name then
        idx = A.MacroIndex(name)
        if idx > 0 and A.MacroBody(idx) == ui.macroBody then -- ours, unchanged
        else idx, name = nil, nil end
    end
    if idx then A.EditMacro(idx, name, body) else
        for n = 1, 9 do
            local cand = n == 1 and "WTT" or ("WTT" .. n)
            if A.MacroIndex(cand) == 0 then name = cand; break end
        end
        if not name then ns.Slash.Print(L["No free macro name between WTT and WTT9."]); return end
        if not A.CreateMacro(name, body) then ns.Slash.Print(L["The macro could not be created. The macro slots may be full."]); return end
    end
    ui.macroName, ui.macroBody = name, body
    ns.Slash.Print(L["Macro %s is set. Drag it to a bar and click it."]:format(name))
end

ns.Start(function()
    local function apply() Card.ApplyPosition(); Card.ApplyAppearance() end
    ns.Settings.onChange = apply
    local db = ns.addon.db
    for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
        db.RegisterCallback(Card, event, apply)
    end
end)
