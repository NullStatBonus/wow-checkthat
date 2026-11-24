-- /ct commands. Run(args, deps) is plain Lua: it returns the lines to print and calls deps for anything
-- that touches the game, so tests can drive it with fakes.
-- deps = { open(page), card(), importPrompt(), export(), macro(), reload(), report(), confirmClear(), setDebug(on), verdict(cmd, note), endRun() }
local _, ns = ...
local L = ns.L

local Slash = {}
ns.Slash = Slash

Slash.pages = { home = true, plans = true, appearance = true, advanced = true, about = true }

local ADDONS = { KeepThat = true, DontDoThat = true, ClosestVendor = true, CheckThat = true }

local function pageList() return L["Pages: home, plans, appearance, advanced, about."] end

-- Chat reads | as an escape: text from a plan or a character name is shown with its bars doubled.
function Slash.Esc(text) return (tostring(text):gsub("|", "||")) end

function Slash.Print(text)
    if ns.addon then ns.addon:Print(text) elseif print then print(text) end
end

function Slash.Run(args, deps)
    local cmd, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local App = ns.App
    local noArgs = { import = true, export = true, macro = true, reload = true, fact = true, undo = true, back = true, next = true, ["end"] = true }
    if noArgs[cmd] and rest ~= "" then return { L["Usage: /ct %s takes no arguments."]:format(cmd) } end
    if cmd == "" then deps.card(); return {}
    elseif cmd == "settings" then
        local page = rest:lower(); if page == "" then page = "home" end
        if page:find("%s") or not Slash.pages[page] then return { pageList() } end
        deps.open(page); return {}
    elseif cmd == "get" or cmd == "set" then
        local key, value = rest:match("^(%S+)%s*(.-)$")
        key = key and key:lower()
        if not key or (cmd == "get" and value ~= "") or (cmd == "set" and (value == "" or value:find("%s"))) then
            return { L["Usage: /ct get <key> or /ct set <key> <value>. Use /ct help appearance for keys."] }
        end
        if cmd == "get" then
            if not ns.Settings.keys[key] then return { ns.Settings.Syntax(key) } end
            return { L["%s = %s"]:format(key, ns.Settings.Value(key)) }
        end
        local _, reply = ns.Settings.Set(key, value:lower()); return { reply }
    elseif cmd == "help" then
        local topic = rest:lower()
        if topic:find("%s") then return { L["Topics: appearance, diagnostics, runs."] } end
        if topic == "appearance" then return {
            L["Keys: card.scale (50-200), card.background-opacity (0-100), card.text-opacity (0-100), card.locked (on or off)."],
            L["Example: /ct set card.text-opacity 80. Open /ct settings appearance for the same options."] }
        elseif topic == "diagnostics" then return { L["Diagnostics: /ct debug on, /ct debug off, /ct log, /ct log clear (confirmation required), /ct fact (report a test fact during a run)."] }
        elseif topic == "runs" then return {
            L["Runs: /ct import, /ct start <addon>, /ct end, /ct pass, /ct partial [note], /ct fail [note], /ct skip, /ct undo, /ct back, /ct next, /ct export, /ct macro, /ct reload."] }
        elseif topic ~= "" then return { L["Topics: appearance, diagnostics, runs."] } end
        return { L["Help: /ct help appearance, /ct help diagnostics, /ct help runs. Open /ct settings [page] or read /ct status [topic]."] }
    elseif cmd == "status" then
        local topic = rest:lower()
        if topic ~= "" and topic ~= "run" and topic ~= "settings" then return { L["Topics: run, settings."] } end
        App.Log("status requested")
        if topic == "run" then return { App.Status() } end
        if topic == "settings" then return ns.Settings.Status() end
        local db = ns.addon and ns.addon.db
        local out = { App.Status(), db and ((db:GetCurrentProfile() == "Default") and L["Settings scope: shared."] or L["Settings scope: this character."]) or nil }
        for _, line in ipairs(ns.Settings.Status()) do out[#out + 1] = line end
        return out
    elseif cmd == "debug" then
        local v = rest:lower()
        if v ~= "on" and v ~= "off" then return { L["Usage: /ct debug on or /ct debug off."] } end
        deps.setDebug(v == "on")
        App.Log("debug " .. v)
        return { v == "on" and L["Debug recording is on."] or L["Debug recording is off."] }
    elseif cmd == "log" then
        local sub = rest:lower()
        if sub == "" then deps.report(); return {} end
        if sub == "clear" then deps.confirmClear(); return {} end
        return { L["Usage: /ct log or /ct log clear."] }
    elseif cmd == "import" then deps.importPrompt(); return {}
    elseif cmd == "start" then
        local addon = rest
        if addon == "" then
            local run = App.Current()
            addon = run and run.addon or ""
        end
        if not ADDONS[addon] then return { L["Usage: /ct start <addon name>."] } end
        local run, err = App.Start(addon)
        if not run then return { err } end
        deps.card(true) -- show, never toggle: an open card would hide the new run
        return { L["Started %s."]:format(run.runId) }
    elseif cmd == "pass" or cmd == "partial" or cmd == "fail" or cmd == "skip" then
        return deps.verdict(cmd, rest ~= "" and rest or nil)
    elseif cmd == "back" or cmd == "next" then
        if not App.Goto(cmd == "back" and -1 or 1) then return { L["There is no run."] } end
        deps.card(true)
        return {}
    elseif cmd == "undo" then
        if not App.Undo() then return { L["Nothing to undo."] } end
        deps.card(true)
        return { L["Undone."] }
    elseif cmd == "end" then
        local run, err = App.CanEnd()
        if not run then return { err } end
        deps.endRun()
        return {}
    elseif cmd == "export" then deps.export(); return {}
    elseif cmd == "fact" then
        local ok, why = ns.Facts.Report("CheckThat", "selftest", 1)
        if ok then return { L["Reported the test fact."] } end
        if why == "no run is open" then return { L["No run is open, so the test fact was not recorded."] } end
        return { L["The test fact was not recorded."] }
    elseif cmd == "macro" then deps.macro(); return {}
    elseif cmd == "reload" then deps.reload(); return {}
    end
    return { L["Unknown command. Use /ct help."] }
end

function Slash.Register(addon)
    local deps = {
        open = function(page) ns.Options.Open(page) end,
        card = function(show) if ns.Card then if show then ns.Card.Show() else ns.Card.Toggle() end end end,
        importPrompt = function() if ns.Card then ns.Card.ImportPrompt() end end,
        export = function() if ns.Card then ns.Card.ExportNow() end end,
        macro = function() if ns.Card then ns.Card.MakeMacro() end end,
        reload = function() ns.Adapter.Reload() end,
        report = function() ns.Export.Show(L["CheckThat debug report"], ns.Log.Report()) end,
        setDebug = function(on) addon.db.profile.debug = on and true or false end,
        confirmClear = function()
            ns.Adapter.Confirm(L["Clear the debug log? Plans, runs and settings stay."], function()
                ns.Log.Clear(); Slash.Print(L["Debug log cleared."])
            end)
        end,
        endRun = function() if ns.Card then ns.Card.ConfirmEnd() end end,
        verdict = function(cmd, note)
            local a, err, step = ns.App.Verdict(cmd, note)
            if ns.Card then ns.Card.AfterVerdict(step); ns.Card.Refresh() end
            if not a then return { err } end
            return { L["Step %s%s."]:format(a.verdict, a.evidence and (" (" .. a.evidence .. ")") or "") }
        end,
    }
    local function handler(msg)
        for _, line in ipairs(Slash.Run(msg, deps)) do Slash.Print(line) end
    end
    addon:RegisterChatCommand("ct", handler)
    addon:RegisterChatCommand("checkthat", handler)
end
