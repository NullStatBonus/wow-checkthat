-- The settings pages. Each page is a pure function that returns an AceConfig group, so tests can build and
-- drive them without the game. Layout, sizes and wording follow DESIGN.md.
local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local APP = "CheckThat"
Options.state = {}

local function profile() return ns.Settings.profile() end

local function page(name, order) return { type = "group", name = name, order = order, args = {} } end

-- Widget counters per group, kept outside the groups: AceConfig rejects any field it does not know.
local counts = setmetatable({}, { __mode = "k" })
local function add(group, key, widget)
    counts[group] = (counts[group] or 0) + 1
    widget.order = counts[group]
    group.args[key] = widget
    return widget
end

-- Body text is explicit neutral #DDDDDD unless it already carries a color.
local function neutral(value)
    if type(value) == "function" then
        return function(...) return neutral(value(...)) end
    end
    if type(value) ~= "string" or value == " " or value:find("^|c") then return value end
    return "|cffdddddd" .. value .. "|r"
end
Options.Neutral = neutral

local function text(group, key, body, hidden)
    return add(group, key, { type = "description", fontSize = "medium", width = "full", name = neutral(body), hidden = hidden })
end
local function grey(value) return "|cffaaaaaa" .. value .. "|r" end
local function note(group, key, body, hidden)
    return add(group, key, { type = "description", fontSize = "small", width = "full", name = body, hidden = hidden })
end
local function gap(group, key)
    return add(group, key, { type = "description", fontSize = "small", width = "full", name = " " })
end
local function introduction(group, heading, purpose)
    add(group, "pageTitle", { type = "header", name = heading })
    text(group, "intro", purpose)
    gap(group, "introGap")
end

function Options.Notify()
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if reg then reg:NotifyChange(APP) end
end

local function planValues()
    local out = {}
    for addon, rec in pairs(ns.App.db and ns.App.db.plans or {}) do out[addon] = addon .. " - " .. rec.plan.title end
    return out
end

function Options.Home(order)
    local g = page(L["Home"], order)
    introduction(g, L["Run a test plan"], L["Import a plan, start a run, and work through the checklist. CheckThat never plays for you."])
    add(g, "h_run", { type = "header", name = L["Current run"] })
    text(g, "runStatus", function() return ns.App.db and ns.App.Status() or L["No run."] end)
    add(g, "openCard", { type = "execute", name = L["Open checklist"], func = function() ns.Card.Show() end })
    add(g, "export", { type = "execute", name = L["Export results"], func = function() ns.Card.ExportNow() end,
        disabled = function() return not (ns.App.db and ns.App.Current()) end })
    gap(g, "g1")
    add(g, "h_start", { type = "header", name = L["Start a run"] })
    note(g, "startHelp", grey(L["Import a plan first. Pick a plan, then select Start run. Each plan keeps its own runs."]))
    add(g, "import", { type = "execute", name = L["Import a plan"], func = function() ns.Card.ImportPrompt() end })
    add(g, "pick", { type = "select", width = 1.5, name = L["Plan"], values = planValues,
        get = function() return Options.state.pick end, set = function(_, v) Options.state.pick = v end })
    add(g, "start", { type = "execute", name = L["Start run"],
        disabled = function() return not Options.state.pick or not (ns.App.db and ns.App.db.plans[Options.state.pick]) end,
        func = function()
            local run, err = ns.App.Start(Options.state.pick)
            if run then ns.Card.Show() else ns.Slash.Print(err) end
            Options.Notify()
        end })
    gap(g, "g2")
    text(g, "next", L["Set the card size and opacity in Appearance. Collect problem reports in Advanced."])
    return g
end

function Options.Plans(order)
    local g = page(L["Plans"], order)
    introduction(g, L["Imported plans"], L["Each plan lists the steps for one addon. A run keeps the plan it started with."])
    text(g, "list", function()
        local lines = {}
        for addon, rec in pairs(ns.App.db and ns.App.db.plans or {}) do
            local steps = 0
            for _, s in ipairs(rec.plan.sections) do steps = steps + #s.steps end
            lines[#lines + 1] = L["%s: %s, %d steps, digest %s"]:format(addon, rec.plan.title, steps, tostring(rec.digest))
        end
        table.sort(lines)
        return #lines > 0 and table.concat(lines, "\n") or L["No plans are imported. Use Import a plan in Home."]
    end)
    gap(g, "g1")
    add(g, "h_remove", { type = "header", name = L["Remove a plan"] })
    note(g, "removeHelp", grey(L["Removing a plan keeps its runs and results."]))
    add(g, "pick", { type = "select", width = 1.5, name = L["Plan"], values = planValues,
        get = function() return Options.state.remove end, set = function(_, v) Options.state.remove = v end })
    add(g, "remove", { type = "execute", name = L["Remove plan"],
        confirm = L["Remove this plan? Runs and results stay."],
        disabled = function() return not Options.state.remove or not (ns.App.db and ns.App.db.plans[Options.state.remove]) end,
        func = function() ns.App.db.plans[Options.state.remove] = nil; Options.state.remove = nil; Options.Notify() end })
    return g
end

local function slider(group, key, name, desc)
    local k = ns.Settings.keys[key]
    return add(group, key, { type = "range", width = 1.5, name = name, desc = desc, min = k.min, max = k.max, step = 1,
        get = function() return ns.Settings.Get(key) end,
        set = function(_, v) ns.Settings.Set(key, v) end })
end

function Options.Appearance(order)
    local g = page(L["Appearance"], order)
    introduction(g, L["Checklist card"], L["Set size, opacity and position here. The card background is black."])
    add(g, "h_look", { type = "header", name = L["Size and opacity"] })
    slider(g, "card.scale", L["Scale"], L["Resize the card from 50 to 200 percent."])
    slider(g, "card.background-opacity", L["Background opacity"], L["The background is pure black. At 0 no background or border is drawn."])
    slider(g, "card.text-opacity", L["Text opacity"], L["Dim the card text."])
    gap(g, "g1")
    add(g, "h_pos", { type = "header", name = L["Position"] })
    note(g, "posHelp", grey(L["Drag the card to move it. Select Lock position to stop it moving."]))
    add(g, "card.locked", { type = "toggle", width = "full", name = L["Lock position"],
        get = function() return ns.Settings.Get("card.locked") end,
        set = function(_, v) ns.Settings.Set("card.locked", v) end })
    add(g, "reset", { type = "execute", name = L["Reset position"], func = function() ns.Settings.ResetPosition() end })
    note(g, "resetHelp", grey(L["Reset position changes only the position."]))
    return g
end

local function db() return ns.addon and ns.addon.db end

function Options.CharacterProfileOn()
    local d = db()
    return d ~= nil and d:GetCurrentProfile() ~= "Default"
end

function Options.SetCharacterProfile(on)
    local d = db()
    if not d then return end
    d:SetProfile(on and d.keys.char or "Default")
    ns.Settings.onChange()
end

function Options.Advanced(order)
    local g = page(L["Advanced"], order)
    introduction(g, L["Settings scope and troubleshooting"], L["Set the settings scope or collect a problem report. Run a plan in Home."])
    add(g, "h_profile", { type = "header", name = L["Profile"] })
    note(g, "profileContext", grey(L["Select separate settings to use this character’s profile. Clear the checkbox to use shared settings. Both profiles keep their saved values. Plans and runs are shared."]))
    add(g, "charProfile", {
        type = "toggle", width = "full", name = L["Use separate settings for this character"],
        confirm = L["Switch settings scope? Existing settings in both scopes are retained; no settings are copied."],
        get = Options.CharacterProfileOn,
        set = function(_, value) Options.SetCharacterProfile(value) end,
    })
    gap(g, "g1")
    add(g, "h_debug", { type = "header", name = L["Debug"] })
    add(g, "debug", {
        type = "toggle", width = "full", name = L["Record debug information"],
        get = function() return profile().debug end,
        set = function(_, value) profile().debug = value and true or false; ns.App.Log("debug " .. (value and "on" or "off")) end,
    })
    note(g, "debugHelp", grey(L["Turn recording on. Repeat the problem. Open the report. Press Ctrl+A, then Ctrl+C to copy it. Turn recording off."]))
    note(g, "clearHelp", grey(L["Use /ct log clear to clear diagnostics after confirmation. Plans, runs and settings stay the same."]))
    add(g, "report", { type = "execute", width = 1.5, name = L["Show debug report"],
        func = function() ns.Export.Show(L["CheckThat debug report"], ns.Log.Report()) end })
    return g
end

function Options.About(order)
    local g = page(L["About"], order)
    add(g, "title", { type = "description", fontSize = "large", width = "full", name = L["CheckThat"] })
    note(g, "version", grey(L["Version %s"]:format(tostring(ns.version))))
    gap(g, "g0")
    text(g, "what", L["Walks you through the in-game test plans for your addons and records evidence for review."])
    gap(g, "g1")
    add(g, "h_cmds", { type = "header", name = L["Commands"] })
    local commands = {
        { "ct", "/ct", L["Open the checklist."] },
        { "import", "/ct import", L["Paste a plan string."] },
        { "start", "/ct start <addon>", L["Start a run for an imported plan."] },
        { "debug", "/ct debug on", L["Record diagnostics while you repeat a problem."] },
        { "log", "/ct log", L["Copy the debug report to share it."] },
    }
    for _, c in ipairs(commands) do
        text(g, "cmd_" .. c[1], L["|cffdddddd%s|r  %s"]:format(c[2], grey(c[3])))
    end
    gap(g, "helpGap")
    add(g, "h_help", { type = "header", name = L["Find the right command"] })
    text(g, "helpAppearance", L["/ct help appearance - card settings and valid values."])
    text(g, "helpRuns", L["/ct help runs - importing plans, verdicts and exports."])
    text(g, "helpDiagnostics", L["/ct help diagnostics - recording, copying and clearing diagnostic reports."])
    note(g, "commandHelp", grey(L["Use /ct status to check settings. Use /ct get <key> to read a value. Use /ct set <key> <value> to change it."]))
    return g
end

Options.PAGES = { { "home", "Home" }, { "plans", "Plans" }, { "appearance", "Appearance" }, { "advanced", "Advanced" }, { "about", "About" } }

function Options.Build()
    return {
        type = "group", name = L["CheckThat"], childGroups = "tree",
        args = { home = Options.Home(1), plans = Options.Plans(2), appearance = Options.Appearance(3),
            advanced = Options.Advanced(4), about = Options.About(5) },
    }
end

function Options.Open(pageName)
    local dialog = LibStub("AceConfigDialog-3.0")
    ns.Adapter.CloseGameSettings()
    dialog:Open(APP)
    dialog:SelectGroup(APP, pageName or "home")
end

local built
function Options.Tree()
    if not built then built = Options.Build() end
    return built
end

ns.Start(function(addon)
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(APP, Options.Tree)
    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:SetDefaultSize(APP, 600, 460)
    dialog:AddToBlizOptions(APP, L["CheckThat"], nil, "home")
    local names = { plans = L["Plans"], appearance = L["Appearance"], advanced = L["Advanced"], about = L["About"] }
    for _, key in ipairs({ "plans", "appearance", "advanced", "about" }) do
        dialog:AddToBlizOptions(APP, names[key], L["CheckThat"], key)
    end
end)
