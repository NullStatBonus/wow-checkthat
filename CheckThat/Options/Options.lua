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
local function gap(group, key, hidden)
    return add(group, key, { type = "description", fontSize = "small", width = "full", name = " ", hidden = hidden })
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
    local TINT = { red = "|cffff6666", yellow = "|cffffd100", green = "|cff66ff66", blue = "|cff80bfff", grey = "|cffaaaaaa", off = "|cff888888" }
    text(g, "categories", function()
        if not ns.App.db then return "" end
        local rows, overall, sum = ns.App.Categories()
        if not rows or #rows < 2 then return "" end
        local lines = {}
        for _, r in ipairs(rows) do lines[#lines + 1] = TINT[r.state] .. ns.App.CategoryLine(r) .. "|r" end
        lines[#lines + 1] = L["Overall: %s, %d passed, %d failed, %d open"]:format(ns.App.StateWord(overall, sum), sum.pass, sum.fail, sum.open)
        return table.concat(lines, "\n")
    end, function()
        local rows = ns.App.db and ns.App.Categories()
        return not rows or #rows < 2
    end)
    add(g, "openCard", { type = "execute", name = L["Open checklist"], func = function() ns.Card.Show() end })
    add(g, "export", { type = "execute", name = L["Export results"], func = function() ns.Card.ExportNow() end,
        disabled = function() return not (ns.App.db and ns.App.Current()) end })
    gap(g, "g1")
    add(g, "h_start", { type = "header", name = L["Start a run"] })
    note(g, "startHelp", grey(L["Import a plan first. Select a plan. Select the categories to test. Select Start run. Each plan keeps its own runs."]))
    add(g, "import", { type = "execute", name = L["Import a plan"], func = function() ns.Card.ImportPrompt() end })
    add(g, "pick", { type = "select", width = 1.5, name = L["Plan"], values = planValues,
        get = function() return Options.state.pick end, set = function(_, v) Options.state.pick = v; Options.state.catPage = nil end })
    -- One checkbox per category of the picked plan, in plan order, all checked until one is cleared.
    local SLOTS = 24
    local function picks()
        return ns.App.db and Options.state.pick and ns.App.Picks(Options.state.pick) or {}
    end
    local function anyPicked()
        local list = picks()
        if #list < 2 then return true end
        for _, c in ipairs(list) do if c.picked and c.steps > 0 then return true end end
        return false
    end
    local function pages() return math.max(1, math.ceil(#picks() / SLOTS)) end
    local function page() return math.min(Options.state.catPage or 0, pages() - 1) end
    local function at(i) return picks()[page() * SLOTS + i] end
    for i = 1, SLOTS do
        add(g, "cat" .. i, { type = "toggle", width = "full",
            name = function()
                local c = at(i)
                if not c then return "" end
                return c.steps == 1 and L["%s: 1 step"]:format(c.title) or L["%s: %d steps"]:format(c.title, c.steps)
            end,
            hidden = function() return #picks() < 2 or not at(i) end,
            get = function() local c = at(i); return c and c.picked end,
            set = function(_, v)
                local c = at(i)
                if c then ns.App.SetPick(Options.state.pick, c.id, v); if ns.Card and ns.Card.Refresh then ns.Card.Refresh() end end
            end })
    end
    note(g, "pickNone", grey(L["Select at least one category."]), function() return anyPicked() end)
    add(g, "pickPage", { type = "description", fontSize = "small", width = "full",
        name = function()
            local n, first = #picks(), page() * SLOTS
            return grey(L["Showing %d to %d of %d."]:format(first + 1, math.min(n, first + SLOTS), n))
        end, hidden = function() return #picks() <= SLOTS end })
    add(g, "pickPrev", { type = "execute", width = 0.6, name = L["Previous page"],
        hidden = function() return #picks() <= SLOTS end, disabled = function() return page() == 0 end,
        func = function() Options.state.catPage = page() - 1; Options.Notify() end })
    add(g, "pickNext", { type = "execute", width = 0.6, name = L["Next page"],
        hidden = function() return #picks() <= SLOTS end, disabled = function() return page() >= pages() - 1 end,
        func = function() Options.state.catPage = page() + 1; Options.Notify() end })
    add(g, "start", { type = "execute", name = L["Start run"],
        disabled = function() return not Options.state.pick or not (ns.App.db and ns.App.db.plans[Options.state.pick]) or not anyPicked() end,
        func = function()
            local run, err = ns.App.Start(Options.state.pick, ns.App.PickedIds(Options.state.pick))
            if run then ns.Card.Show() else ns.Slash.Print(err) end
            Options.Notify()
        end })
    gap(g, "g2")
    local function noRuns() return not (ns.App.db and #ns.App.Runs() > 0) end
    local function chosen()
        local id = Options.state.run
        return id and ns.App.db and ns.App.db.runs[id] and id or nil
    end
    local function runValues()
        local out = {}
        for _, row in ipairs(ns.App.db and ns.App.Runs() or {}) do out[row.id] = row.text end
        return out
    end
    local function runOrder()
        local out = {}
        for _, row in ipairs(ns.App.db and ns.App.Runs() or {}) do out[#out + 1] = row.id end
        return out
    end
    add(g, "h_runs", { type = "header", name = L["Past runs"], hidden = noRuns })
    note(g, "runsHelp", grey(L["Pick a run in the list. Each row shows the pass, fail and open counts. Select Open run to see it on the checklist. Select Export run to copy its results. Select Delete run to remove it."]), noRuns)
    add(g, "runPick", { type = "select", width = "full", name = L["Run"], hidden = noRuns, values = runValues, sorting = runOrder,
        get = chosen, set = function(_, v) Options.state.run = v end })
    add(g, "runOpen", { type = "execute", name = L["Open run"], hidden = noRuns,
        confirm = function()
            local id = chosen()
            if not (id and ns.App.OpenAsks(id)) then return end
            ns.App.Log("run open asked " .. id)
            if ns.App.OpenReplacesRun(id) then return L["Open this run? Your current run leaves the checklist. CheckThat keeps it in the list until newer runs push it out."] end
            return L["Open this run to look at it? Your current run stays as it is."]
        end,
        disabled = function()
            local id = chosen()
            local run = id and ns.App.db.runs[id]
            return not run or (not run.endedAt and run.character ~= ns.App.Character())
        end,
        func = function()
            local run, err = ns.App.OpenRun(chosen())
            if run then ns.Card.Show(); ns.Card.Refresh() else ns.Slash.Print(err) end
            Options.Notify()
        end })
    add(g, "runExport", { type = "execute", name = L["Export run"], hidden = noRuns, disabled = function() return not chosen() end,
        func = function() ns.Card.ExportNow(chosen()) end })
    add(g, "runDelete", { type = "execute", name = L["Delete run"], hidden = noRuns, disabled = function() return not chosen() end,
        confirm = function() -- a string would name a handler method, so the text comes from a function
            local text = chosen() and ns.App.RunText(chosen()) or ""
            if chosen() then ns.App.Log("run delete asked " .. chosen()) end
            return L["Delete the run %s? CheckThat removes its results. You cannot restore them."]:format((ns.Slash.Esc(text):gsub("%%", "%%%%")))
        end,
        func = function()
            local ok, err = ns.App.DeleteRun(chosen())
            if not ok then ns.Slash.Print(err) end
            Options.state.run = nil
            ns.Card.Refresh()
            Options.Notify()
        end })
    gap(g, "g3", noRuns)
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
        confirm = function() return L["Remove this plan? Runs and results stay."] end,
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
        confirm = function() return L["Switch settings scope? Existing settings in both scopes are retained; no settings are copied."] end,
        get = Options.CharacterProfileOn,
        set = function(_, value) Options.SetCharacterProfile(value) end,
    })
    gap(g, "g1")
    add(g, "h_store", { type = "header", name = L["Stored runs"] })
    note(g, "storeHelp", grey(L["Set how many runs to keep. When you start a run, CheckThat deletes the oldest runs above this number. The current run of each character always stays."]))
    add(g, "runLimit", { type = "range", width = 1.5, name = L["Runs to keep"],
        min = ns.App.RUN_LIMIT.min, max = ns.App.RUN_LIMIT.max, step = 1,
        get = function() return ns.App.db and ns.App.RunLimit() or ns.App.RUN_LIMIT.default end,
        set = function(_, v)
            if not ns.App.db then return end
            ns.App.db.runLimit = v -- the slider fires while it is dragged: nothing is deleted until a run starts
            Options.Notify()
        end })
    gap(g, "g1b")
    add(g, "h_macro", { type = "header", name = L["Macro"] })
    add(g, "macroFollow", {
        type = "toggle", width = "full", name = L["Keep the CT macro on the current step"],
        get = function() return profile().macroFollow end,
        set = function(_, value)
            profile().macroFollow = value and true or false
            ns.App.Log("macroFollow " .. (value and "on" or "off"))
            if ns.Card then ns.Card.FollowMacro(true); ns.Card.Refresh() end
        end,
    })
    note(g, "macroFollowHelp", grey(L["CheckThat rewrites the CT macro with the commands of the current step. Put the macro on a bar and bind a key to it. The macro never records a result. You still press a result key. It changes only out of combat."]))
    gap(g, "g2")
    add(g, "h_selfcheck", { type = "header", name = L["Self-check"] })
    add(g, "loginCheck", {
        type = "toggle", width = "full", name = L["Check entry points after login"],
        get = function() return profile().loginCheck end,
        set = function(_, value) profile().loginCheck = value and true or false; ns.App.Log("loginCheck " .. (value and "on" or "off")) end,
    })
    note(g, "loginCheckHelp", grey(L["After login and outside combat, CheckThat calls the functions your imported plans name and other addons registered. It prints one line in chat. It runs code from those addons, so leave it off unless you test them. It takes effect at the next login."]))
    gap(g, "g3")
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
