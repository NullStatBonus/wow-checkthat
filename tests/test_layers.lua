local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- The text window (report, results string, plan import) must draw above the card and the protected Run button.
local st = H.stubClient()
local real = _G.CreateFrame
_G.CreateFrame = function(kind, name, ...)
    local f = real(kind, name, ...)
    f.SetFrameStrata = function(self, s) self.strata = s end -- the stub does not keep it; remember it for the test
    return f
end
H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
test("the text window draws above the card and the Run button", function()
    CheckThatDB = nil
    ns.addon:OnInitialize(); ns.addon:OnEnable()
    ns.Card.Show()
    local card = _G.CheckThatCard
    T.ok(card.secure, "the Run button exists")
    ns.Export.Prompt("Results", "!CT1!x", nil, "Close", "", true, { choices = {} }) -- the stub frame answers any missing field with a function
    local box = _G.CheckThatTextBox
    T.ok(box, "the window exists")
    T.ok(RANK[box.strata], "window strata is set: " .. tostring(box.strata))
    T.ok(RANK[card.secure.strata] and RANK[box.strata] > RANK[card.secure.strata],
        ("window (%s) must be above the Run button (%s)"):format(tostring(box.strata), tostring(card.secure.strata)))
    T.ok(RANK[box.strata] > RANK[rawget(card, "strata") or "MEDIUM"], "and above the card")
end)
test("the report window is the AceGUI frame the sibling addons use", function()
    local gui = LibStub("AceGUI-3.0")
    local create, release = gui.Create, gui.Release
    local made, freed = {}, {}
    local function widget(kind)
        local w = { kind = kind, callbacks = {} }
        function w:SetTitle(t) self.title = t end
        function w:SetStatusText(t) self.status = t end
        function w:SetLayout() end
        function w:SetCallback(n, fn) self.callbacks[n] = fn end
        function w:AddChild(c) self.child = c end
        function w:SetLabel() end
        function w:DisableButton(b) self.buttonOff = b end
        function w:SetText(t) self.text = t end
        function w:SetFocus() self.focused = true end
        function w:HighlightText(...) self.selected = select("#", ...) == 0 end
        made[#made + 1] = w
        return w
    end
    gui.Create = function(_, kind) return widget(kind) end
    gui.Release = function(_, w) freed[#freed + 1] = w end
    ns.Export.Show("Report", "line one\nline two")
    ns.Export.Show("Second", "other")
    gui.Create, gui.Release = create, release
    local frame, box = made[1], made[2]
    T.eq(frame.kind, "Frame"); T.eq(box.kind, "MultiLineEditBox"); T.eq(frame.child, box)
    T.eq(frame.title, "Report")
    T.eq(frame.status, "Press Ctrl+A to select everything, then Ctrl+C to copy.")
    T.eq(box.text, "line one\nline two"); T.ok(box.buttonOff and box.focused and box.selected, "no button, focused, all selected")
    box.text = "typed"; box.callbacks.OnTextChanged(box)
    T.eq(box.text, "line one\nline two", "typing is undone")
    T.eq(freed[1], frame, "a second report replaces the first window")
end)
test("the import window is the same frame, with a recent plans list and an Import button", function()
    local gui = LibStub("AceGUI-3.0")
    local create, release = gui.Create, gui.Release
    local made, freed = {}, {}
    gui.Create = function(_, kind)
        local w = { kind = kind, callbacks = {}, args = {} }
        if kind == "MultiLineEditBox" then w.button = { SetText = function(b, t) b.text = t end } end -- the widget's own button frame
        setmetatable(w, { __index = function(t, k) return function(self, ...) self.args[k] = { ... } end end })
        function w:SetCallback(n, fn) self.callbacks[n] = fn end
        function w:AddChild(c) end
        made[#made + 1] = w
        return w
    end
    gui.Release = function(_, w) freed[#freed + 1] = w end
    local got, chose
    ns.Export.Prompt("Paste a plan", "", function(s) got = s end, "Import", nil, nil,
        { choices = { { id = "A", text = "Plan A" }, { id = "B", text = "Plan B" } }, onChoose = function(id) chose = id end })
    local frame, dd, box = made[1], made[2], made[3]
    T.eq(frame.kind, "Frame"); T.eq(dd.kind, "Dropdown"); T.eq(box.kind, "MultiLineEditBox")
    T.eq(frame.args.SetTitle[1], "Paste a plan")
    T.eq(box.button.text, "Import", "the box carries the Import button")
    T.eq(dd.args.SetList[1].A, "Plan A"); T.eq(dd.args.SetList[2][2], "B", "plans keep their order")
    box.callbacks.OnEnterPressed(box, "OnEnterPressed", "!CT1!abc")
    gui.Create, gui.Release = create, release
    T.eq(got, "!CT1!abc", "Import hands the text over"); T.eq(freed[#freed], frame, "and closes the window")
end)
test("the AceGUI frame draws above the card and the Run button", function()
    local gui = LibStub("AceGUI-3.0")
    local w = gui:Create("Frame")
    local card = _G.CheckThatCard
    T.ok(RANK[w.frame.strata] and RANK[w.frame.strata] > RANK[card.secure.strata], "frame (" .. tostring(w.frame.strata) .. ") above the Run button")
end)
test("the report falls back to the plain window when AceGUI is missing", function()
    local gui = LibStub("AceGUI-3.0")
    local create = gui.Create
    gui.Create = nil
    ns.Export.Show("Report", "fallback text")
    gui.Create = create
    T.ok(_G.CheckThatTextBox and _G.CheckThatTextBox.shown, "the plain window opens")
end)
-- The stub widgets above answer any method, so they cannot catch a call the real widget lacks (in game the import window
-- fell back to the plain one: MultiLineEditBox has no SetButtonText). Check each call against the shipped widget source.
test("every method the text windows call on an AceGUI widget exists in the shipped widget", function()
    local function read(p) local f = assert(io.open(p)); local s = f:read("*a"); f:close(); return s end
    local core = read("CheckThat/Libs/AceGUI-3.0/AceGUI-3.0.lua")
    local function methods(widget)
        local have = {}
        for m in core:gmatch("WidgetBase%.(%w+) = function") do have[m] = true end
        for m in core:gmatch("WidgetContainerBase%.(%w+) = function") do have[m] = true end
        local f = io.open(("CheckThat/Libs/AceGUI-3.0/widgets/AceGUIWidget-%s.lua"):format(widget))
        local src = f and f:read("*a") or read(("CheckThat/Libs/AceGUI-3.0/widgets/AceGUIContainer-%s.lua"):format(widget))
        if f then f:close() end
        for m in src:gmatch('%["(%w+)"%]%s*=%s*function') do have[m] = true end
        for m in src:gmatch('self%.(%u%w+)%s*=%s*%w') do have[m] = true end -- DropDown sets its methods one by one
        return have
    end
    local kinds = { w = "Frame", edit = "MultiLineEditBox", dd = "DropDown" }
    local whole = read("CheckThat/Debug/Export.lua")
    -- Only the AceGUI windows: the plain window's own frames (box.edit) are game frames, not AceGUI widgets.
    local src = whole:match("local function aceShow.-\nfunction Export%.Show") .. whole:match("local function aceImport.-\nfunction Export%.Prompt")
    local checked = 0
    for var, widget in pairs(kinds) do
        local have = methods(widget)
        for m in src:gmatch("%f[%w]" .. var .. ":(%w+)%(") do
            checked = checked + 1
            T.ok(have[m], ("%s:%s: the shipped %s widget has no such method"):format(var, m, widget))
        end
    end
    T.ok(checked > 15, "the calls were found: " .. checked)
end)
test("a note goes before the copy hint in the text window (#250)", function()
    local gui = LibStub("AceGUI-3.0")
    local create, release = gui.Create, gui.Release
    local made = {}
    gui.Create = function(_, kind)
        local w = { kind = kind, args = {} }
        setmetatable(w, { __index = function(t, k) return function(self, ...) self.args[k] = { ... } end end })
        made[#made + 1] = w
        return w
    end
    gui.Release = function() end
    T.finally(function() gui.Create, gui.Release = create, release end)
    ns.Export.Show("Results string", "!CT1!x", "The results include your character and realm name.")
    T.eq(made[1].args.SetStatusText[1], "The results include your character and realm name. Press Ctrl+A to select everything, then Ctrl+C to copy.")
    ns.Export.Show("Report", "text")
    T.eq(made[#made - 1].args.SetStatusText[1], "Press Ctrl+A to select everything, then Ctrl+C to copy.", "no note: the hint alone")
    gui.Create = nil
    ns.Export.Show("Results string", "!CT1!x", "The results include your character and realm name.")
    T.eq(_G.CheckThatTextBox.hint:GetText(), "The results include your character and realm name. Press Ctrl+C to copy.", "the plain window says it too")
    _G.CheckThatTextBox:Hide()
end)
test("the plain import window holds each choice to one line inside its button", function()
    local gui = LibStub("AceGUI-3.0")
    local create = gui.Create
    gui.Create = nil
    T.finally(function() gui.Create = create end)
    local long = { { id = "A", text = ("Long plan title "):rep(8) } }
    ns.Export.Prompt("Import a plan", "", function() end, "Import", "hint", nil, { choices = long, onChoose = function() end })
    ns.Export.OpenMenu()
    local b = _G.CheckThatTextBox.menu.items[1]
    local fs = { calls = {} }
    function fs:SetWidth(w) self.calls.width = w end
    function fs:SetWordWrap(on) self.calls.wrap = on end
    rawset(b, "GetFontString", function() return fs end)
    ns.Export.OpenMenu()
    T.eq(fs.calls.wrap, false, "one line, cut with dots")
    T.ok(fs.calls.width and fs.calls.width < 288, "narrower than the 288 button: " .. tostring(fs.calls.width))
    _G.CheckThatTextBox:Hide()
end)
-- Game globals stay in Core/Adapter.lua. UI/ and Debug/ may build their own frames (AGENTS.md, Conventions).
test("Model, Options and Core use no game globals outside the adapter", function()
    local GLOBALS = { "CreateFrame", "UIParent", "InCombatLockdown", "GetTime", "hooksecurefunc", "GameTooltip", "GetBuildInfo" }
    local bad = {}
    local p = io.popen("find CheckThat/Model CheckThat/Options CheckThat/Core -name '*.lua' ! -name Adapter.lua")
    for path in p:lines() do
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            line = " " .. line:gsub("%-%-.*$", "") .. " "
            for _, g in ipairs(GLOBALS) do
                -- a bare name: not a field (x.G, x:G) and not part of a longer name
                if line:find("[^%w_.:]" .. g .. "[^%w_]") then bad[#bad + 1] = ("%s:%d %s"):format(path, n, g) end
            end
            -- C_* namespaces
            if line:find("[^%w_.:\"']C_%u%w*%.") then bad[#bad + 1] = ("%s:%d C_*"):format(path, n) end
        end
    end
    p:close()
    T.ok(#bad == 0, "game globals outside the adapter: " .. table.concat(bad, ", "))
end)
test("no other addon is required: the TOC files declare optional dependencies only", function()
    for _, path in ipairs({ "CheckThat/CheckThat_Vanilla.toc", "CheckThat/CheckThat_Camelot.toc" }) do
        local f = io.open(path); local toc = f:read("*a"); f:close()
        for key in toc:gmatch("\n## (%a+):") do
            T.ok(key ~= "Dependencies" and key ~= "RequiredDeps" and key ~= "Dep", path .. " declares " .. key)
        end
        T.ok(toc:find("## OptionalDeps:", 1, true), path)
    end
end)
test("the error code reads BugGrabber's saved list only through a guarded read", function()
    local f = io.open("CheckThat/Model/Errors.lua"); local src = f:read("*a"); f:close()
    T.ok(src:find('genv and genv.BugGrabberDB', 1, true), "BugGrabberDB is read from the adapter's environment, never as a bare global")
    T.ok(not src:find("[^%w_.]BugGrabberDB"), "no bare BugGrabberDB global")
end)
finish()
