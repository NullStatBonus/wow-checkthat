-- /ct commands. Run(args, deps) is plain Lua: it returns the lines to print and calls deps for anything
-- that touches the game, so tests can drive it with fakes.
-- deps = { census() (returns "started", "busy" or "combat"), open(page), card(), importPrompt(), export(), macro(), reload(), report(), confirmClear(), setDebug(on), verdict(cmd, note), endRun() }
local _, ns = ...
local L = ns.L

local Slash = {}
ns.Slash = Slash

Slash.pages = { home = true, plans = true, appearance = true, advanced = true, about = true }

-- The addon a plan can name, in the spelling of Plan.SLASH, whatever case the player typed.
local function addonName(text)
    local want = tostring(text):lower()
    for name in pairs(ns.Plan.SLASH) do
        if name:lower() == want then return name end
    end
end

-- "Step pass (matched)." in the player's language: the result and the evidence are each a localized word.
function Slash.VerdictLine(a)
    local verdicts = { pass = L["pass"], partial = L["partial"], fail = L["fail"], skip = L["skip"], unverified = L["unverified"] }
    local evidence = { matched = L["matched"], contradicts = L["contradicts"], unverified = L["unverified"], ["diagnostic-only"] = L["diagnostic-only"] }
    local word = verdicts[a.verdict] or tostring(a.verdict)
    local ev = a.evidence and (evidence[a.evidence] or tostring(a.evidence))
    if ev then return L["Step %s (%s)."]:format(word, ev) end
    return L["Step %s."]:format(word)
end

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
    local noArgs = { import = true, export = true, macro = true, reload = true, fact = true, version = true, undo = true, back = true, next = true, ["end"] = true, categories = true, census = true }
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
        elseif topic == "diagnostics" then return { L["Diagnostics: /ct debug on, /ct debug off, /ct log, /ct log clear (confirmation required), /ct fact (report a test fact during a run), /ct census (record the names available in this game session)."] }
        elseif topic == "runs" then return {
            L["Runs: /ct import, /ct start <addon>, /ct end, /ct pass, /ct partial [note], /ct fail [note], /ct skip, /ct undo, /ct back, /ct next, /ct export, /ct macro, /ct macrorun <step id>, /ct reload. Categories: /ct categories, /ct tracker, /ct run <category or step id>, /ct rerun <category>, /ct rerun failed (retries the failed and unverified steps of all categories)."] }
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
        addon = addonName(addon)
        if not addon then return { L["Usage: /ct start <addon name>."] } end
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
    elseif cmd == "categories" then
        local rows, overall, total = App.Categories()
        if not rows then return { L["There is no run."] } end
        local out = {}
        for _, row in ipairs(rows) do out[#out + 1] = Slash.Esc(App.CategoryLine(row)) end -- a title is plan text: chat reads | as an escape
        out[#out + 1] = L["Overall: %s, %d passed, %d failed, %d open"]:format(App.StateWord(overall, total), total.pass, total.fail, total.open)
        return out
    elseif cmd == "tracker" then
        if rest ~= "" then return { L["Usage: /ct tracker takes no arguments."] } end
        deps.tracker()
        return {}
    elseif cmd == "run" or cmd == "rerun" then
        if rest == "" or rest:find("%s") then
            return { cmd == "run" and L["Usage: /ct run <category or step id>."] or L["Usage: /ct rerun <category> or /ct rerun failed."] }
        end
        if cmd == "run" then
            local kind, id = App.Trigger(rest)
            if not kind then return { id } end
            deps.card(true)
            return { L["Showing step %s."]:format(Slash.Esc(id)) }
        end
        local n, title = App.RerunCount(rest)
        if not n then return { title } end
        if n == 0 then return { App.NothingToReopen(rest, title) } end
        deps.confirmRerun(rest, n, title)
        return {}
    elseif cmd == "export" then deps.export(); return {}
    elseif cmd == "version" then
        -- 0.17.0 is the number 1700, so a plan can check "this version or newer" with a fact.
        local v = tostring(ns.version)
        local major, minor, patch = v:match("^(%d+)%.(%d+)%.(%d+)")
        if major then ns.Facts.Report("CheckThat", "version", major * 10000 + minor * 100 + patch) end
        return { L["CheckThat %s"]:format(Slash.Esc(v)) }
    elseif cmd == "census" then
        local r = deps.census()
        if r == "busy" then return { L["A client census is already running."] } end
        if r == "combat" then return { L["Run /ct census after combat ends."] } end
        return { L["Client census started. Wait for the completion message before you reload or log out."] }
    elseif cmd == "fact" then
        local ok, why = ns.Facts.Report("CheckThat", "selftest", 1)
        if ok then return { L["Reported the test fact."] } end
        if why == "no run is open" then return { L["No run is open, so the test fact was not recorded."] } end
        return { L["The test fact was not recorded."] }
    elseif cmd == "selftest" then
        local what = rest:lower()
        if what == "facts" then
            local ok = ns.Facts.Report("CheckThat", "level", 3)
            ok = ns.Facts.Report("CheckThat", "ratio", 0.5) and ok
            ok = ns.Facts.Report("CheckThat", "hit", 1) and ok
            ok = ns.Facts.Report("CheckThat", "hit", 1) and ok
            ok = ns.Facts.Report("CheckThat", "mode", "fast") and ok
            ok = ns.Facts.Report("CheckThat", "flag", true) and ok
            -- A value that changes each call keeps the last lines of the list different, so a count of exactly n or an
            -- absence can be shown (a tail of repeated lines cannot prove where the step began).
            Slash.seq = (Slash.seq or 0) + 1
            ok = ns.Facts.Report("CheckThat", "seq", (ns.Adapter.Now() or 0) * 100 + Slash.seq % 100) and ok
            if ok then return { L["Reported the test facts."] } end
            return { L["No run is open, so the test facts were not recorded."] }
        elseif what == "error" then
            ns.Errors.Hook()
            if ns.Adapter.RaiseTestError("CheckThat self-test error") then return { L["Raised a test error. The game may show its error window."] } end
            return { L["This client has no error handler, so no test error was raised."] }
        end
        return { L["Usage: /ct selftest facts or /ct selftest error."] }
    elseif cmd == "macro" then deps.macro(); return {}
    elseif cmd == "macrorun" then
        if rest == "" or rest:find("%s") then return { L["Usage: /ct macrorun <step id>."] } end
        local line = App.MacroRun(rest)
        return line and { Slash.Esc(line) } or {}
    elseif cmd == "reload" then deps.reload(); return {}
    end
    return { L["Unknown command. Use /ct help."] }
end

function Slash.Register(addon)
    local deps = {
        tracker = function() if ns.Tracker then ns.Tracker.Toggle() end end,
        confirmRerun = function(what, n, title) if ns.Card then ns.Card.ConfirmRerun(what, n, title) end end,
        open = function(page) ns.Options.Open(page) end,
        card = function(show) if ns.Card then if show then ns.Card.Show() else ns.Card.Toggle() end end end,
        importPrompt = function() if ns.Card then ns.Card.ImportPrompt() end end,
        export = function() if ns.Card then ns.Card.ExportNow() end end,
        macro = function() if ns.Card then ns.Card.MakeMacro() end end,
        reload = function() ns.Adapter.Reload() end,
        census = function()
            return ns.Census.Start(function() Slash.Print(L["Client census complete. Type /reload or log out to save it."]) end,
                function() Slash.Print(L["The client census could not read the game's names. The saved census is unchanged."]) end)
        end,
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
            return { Slash.VerdictLine(a) }
        end,
    }
    local function handler(msg)
        for _, line in ipairs(Slash.Run(msg, deps)) do Slash.Print(line) end
    end
    addon:RegisterChatCommand("ct", handler)
    addon:RegisterChatCommand("checkthat", handler)
end
