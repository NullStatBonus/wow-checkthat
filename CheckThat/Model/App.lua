-- Application logic: import, runs, verdicts, export. Testable with a fake env; no frames here.
local _, ns = ...
local L = ns.L
local App = { db = nil, env = _G }
ns.App = App

local function now(self) return (self.env.time and self.env.time()) or 0 end

-- db is the saved global table. opts.debug() says whether recording is on (default: db.log.enabled).
function App.Init(db, env, opts)
    App.env = env or _G
    db.plans = db.plans or {}
    db.planStore = db.planStore or {}
    db.currentByChar = db.currentByChar or {}
    db.runs = db.runs or {}
    db.log = db.log or { entries = {} }
    db.ui = db.ui or {}
    db.ui.shareReload = nil -- a reload request lasts until the next load
    App.db = db
    if ns.Log then
        ns.Log.Bind(db.log, (opts and opts.debug) or function() return db.log.enabled end, function() return now(App) end)
    end
    return db
end

function App.Log(msg)
    if ns.Log then ns.Log.Record("ct", msg) end
end

-- "classic-era" or "forever-camelot", from the interface number (checked by number, not by client name).
function App.Client()
    local gb = App.env.GetBuildInfo
    local toc = 0
    if gb then local _, _, _, t = gb(); toc = t or 0 end
    return (toc or 0) >= 16000 and "forever-camelot" or "classic-era"
end

function App.Build()
    local gb = App.env.GetBuildInfo
    if not gb then return "unknown" end
    local v, b = gb()
    return tostring(v) .. "." .. tostring(b)
end

function App.Character()
    local env = App.env
    local n, r = env.UnitName and env.UnitName("player"), nil
    if env.UnitFullName then
        local fn, fr = env.UnitFullName("player")
        n = fn or n; r = fr
    end
    for _, get in ipairs({ env.GetNormalizedRealmName, env.GetRealmName }) do
        if (r == nil or r == "") and get then r = get() end
    end
    if r == nil or r == "" then r = "?" end
    return (n or "?") .. "-" .. r
end

-- Codec and plan errors are technical English; the player sees one of these sentences.
local function readError(err)
    err = tostring(err)
    if err:find("checksum") then return L["The checksum does not match. The string may be damaged."] end
    if err:find("too large") then return L["The string is too large."] end
    if err:find("version") then return L["This string needs a newer CheckThat."] end
    if err:find("not a CT") then return L["This is not a CheckThat string."] end
    return L["The string is damaged or incomplete."]
end

-- Recently used plans, newest first (max 8). Each entry names a stored plan by digest, so a plan can be chosen
-- again without pasting its string.
App.RECENT_MAX = 8

function App.RememberRecent(plan, digest)
    local list = App.db.ui.recent or {}
    local out = { { digest = digest, addon = plan.addon, title = plan.title, at = now(App) } }
    for _, e in ipairs(list) do
        if e.digest ~= digest and #out < App.RECENT_MAX then out[#out + 1] = e end
    end
    App.db.ui.recent = out
    App.db.ui.lastImport = plan.addon
end

-- Entries whose plan is still stored: { id = digest, text = "Title (Addon)" }.
function App.Recent()
    local out = {}
    for _, e in ipairs(App.db and App.db.ui.recent or {}) do
        if App.db.planStore[e.digest] then out[#out + 1] = { id = e.digest, text = ("%s (%s)"):format(e.title, e.addon) } end
    end
    return out
end

-- Make a recent plan the current one, as if it had just been imported.
function App.UseRecent(digest)
    local plan = App.db.planStore[digest]
    if not plan then return nil, L["That plan is no longer stored. Paste its string again."] end
    App.db.plans[plan.addon] = { plan = plan, digest = digest }
    App.RememberRecent(plan, digest)
    App.db.ui.pendingStart = plan.addon
    App.Log(("reused plan %s digest %s"):format(plan.addon, digest))
    return plan
end

-- A stored plan copy stays only while a run, a loaded plan or a recent-list entry names it.
function App.PrunePlans()
    local keep = {}
    for _, r in pairs(App.db.runs) do if r.planDigest then keep[r.planDigest] = true end end
    for _, p in pairs(App.db.plans) do keep[p.digest] = true end
    for _, e in ipairs(App.db.ui.recent or {}) do keep[e.digest] = true end
    for digest in pairs(App.db.planStore) do
        if not keep[digest] then App.db.planStore[digest] = nil end
    end
end

App.RUN_LIMIT = { default = 20, min = 5, max = 100 }

function App.RunLimit()
    local n = App.db and tonumber(App.db.runLimit)
    if not n then return App.RUN_LIMIT.default end
    return math.max(App.RUN_LIMIT.min, math.min(App.RUN_LIMIT.max, math.floor(n)))
end

-- Runs newest first; ties keep a stable order by id.
local function sortedRuns()
    local list = {}
    for id, run in pairs(App.db.runs) do list[#list + 1] = { id = id, run = run } end
    table.sort(list, function(a, b)
        local x, y = a.run.started or 0, b.run.started or 0
        if x ~= y then return x > y end
        return a.id > b.id
    end)
    return list
end

-- Keep at most RunLimit runs: the oldest go first. A character's current run always stays.
function App.PruneRuns()
    local list, current = sortedRuns(), {}
    for _, id in pairs(App.db.currentByChar) do current[id] = true end
    local excess = #list - App.RunLimit()
    for i = #list, 1, -1 do
        if excess <= 0 then break end
        if not current[list[i].id] then
            App.db.runs[list[i].id] = nil
            excess = excess - 1
            App.Log("run pruned " .. list[i].id)
        end
    end
    App.PrunePlans()
end

-- The run the card shows: an ended run opened from Past runs, else the character's current run.
local function shownId()
    local char = App.Character()
    local v = App.db.ui.view and App.db.ui.view[char]
    if v and App.db.runs[v] then return v end
    return App.db.currentByChar[char]
end
App.ShownId = shownId

local function runText(run)
    local c = ns.Run.Counts(run)
    local when = run.started and App.env.date and App.env.date("%Y-%m-%d %H:%M", run.started) or tostring(run.started or "?")
    return L["%s  %s (%s): %d pass, %d fail, %d open"]:format(when, tostring(run.planTitle or run.addon), tostring(run.character), c.pass, c.fail, c.open)
end

function App.RunText(id)
    local run = App.db.runs[id or ""]
    return run and runText(run) or nil
end

-- Rows for the Runs list, newest first: { id, text, ended, character, current }.
function App.Runs()
    local out = {}
    local cur = App.db.currentByChar[App.Character()]
    for _, e in ipairs(sortedRuns()) do
        out[#out + 1] = { id = e.id, ended = e.run.endedAt ~= nil, character = e.run.character, current = e.id == cur, text = runText(e.run) }
    end
    return out
end

-- Show a stored run on the card. An ended run is only viewed: the character's current run stays as it was.
-- A run that has not ended belongs to the character that started it: it becomes the current run, and the
-- attempt it left open starts again. Another character cannot take it over.
function App.OpenRun(id)
    local run = App.db.runs[id or ""]
    if not run then return nil, L["There is no run."] end
    local char, ui = App.Character(), App.db.ui
    ui.view = ui.view or {}
    if run.endedAt then
        ui.view[char] = App.db.currentByChar[char] ~= id and id or nil
    elseif run.character ~= char then
        return nil, L["That run has not ended and belongs to another character. Export it or delete it."]
    else
        ui.view[char] = nil
        if App.db.currentByChar[char] ~= id then
            App.db.currentByChar[char] = id
            ns.Run.Resume(run, now(App))
        end
    end
    ui.pendingStart = nil
    App.Log("run opened " .. id)
    return run
end

-- True when opening this run would take the card from another unfinished run of this character.
function App.OpenReplacesRun(id)
    local run = App.db.runs[id or ""]
    local cur = App.db.runs[App.db.currentByChar[App.Character()] or ""]
    return run ~= nil and not run.endedAt and cur ~= nil and not cur.endedAt and cur.runId ~= id
end

-- True when opening this run needs the player's accept: another unfinished run of this character is active.
function App.OpenAsks(id)
    local cur = App.db.runs[App.db.currentByChar[App.Character()] or ""]
    return App.db.runs[id or ""] ~= nil and cur ~= nil and not cur.endedAt and cur.runId ~= id
end

function App.DeleteRun(id)
    if not App.db.runs[id or ""] then return nil, L["There is no run."] end
    App.db.runs[id] = nil
    for char, cur in pairs(App.db.currentByChar) do
        if cur == id then App.db.currentByChar[char] = nil end
    end
    for char, v in pairs(App.db.ui.view or {}) do
        if v == id then App.db.ui.view[char] = nil end
    end
    App.PrunePlans()
    App.Log("run deleted " .. id)
    return true
end

-- Import a pasted string. Returns plan table or nil + error text. Nothing is stored on failure.
-- Validator messages are technical English kept for the debug log; the player sees one of these sentences.
local function planReason(first)
    first = tostring(first)
    if first:find("^markdown") then return L["A text in the plan uses backticks or stars. Plans use game color codes."] end
    if first:find("not allowed") then return L["The plan has a command that CheckThat does not allow."] end
    if first:find("addon not supported") then return L["This plan is for an addon this CheckThat does not support."] end
    if first:find("format version") then return L["This string needs a newer CheckThat."] end
    return L["The plan has a missing or wrong field. Export it again from the plan file."]
end

local function sameTable(a, b)
    local x, y = ns.Json.Encode(a), ns.Json.Encode(b)
    return x ~= nil and x == y
end

function App.ImportPlan(str)
    local ok, tbl, err, digest = pcall(ns.Codec.Decode, str)
    if not ok then App.Log("import crashed: " .. tostring(tbl)); return nil, L["The string could not be read. %s"]:format(readError("damaged")) end
    if not tbl then App.Log("import failed: " .. tostring(err)); return nil, L["The string could not be read. %s"]:format(readError(err)) end
    if type(tbl) ~= "table" then return nil, L["The string could not be read. %s"]:format(readError("damaged")) end
    if tbl.kind ~= "plan" then return nil, L["This string holds %s, not a plan."]:format(tostring(tbl.kind):gsub("[^%w ]", "")) end
    local vok, errs = pcall(ns.Plan.Validate, tbl)
    if not vok then errs = { "validator error: " .. tostring(errs) } end
    if #errs > 0 then
        App.Log("import rejected: " .. errs[1])
        return nil, L["The plan is not valid (%d problems). %s"]:format(#errs, planReason(errs[1]))
    end
    -- The checksum is only 32 bits: never let a different plan take over a stored one that a run depends on.
    local key, n = digest, 1
    while App.db.planStore[key] and not sameTable(App.db.planStore[key], tbl) do n = n + 1; key = digest .. "-" .. n end
    digest = key
    App.db.plans[tbl.addon] = { plan = tbl, digest = digest }
    App.db.planStore[digest] = tbl -- runs keep the exact plan they started with
    App.RememberRecent(tbl, digest)
    App.db.ui.pendingStart = tbl.addon -- a new plan takes focus: the card offers Start run, even after a finished run
    App.PrunePlans()
    App.Log(("imported plan %s digest %s"):format(tbl.addon, digest))
    return tbl
end

function App.Ctx(run)
    local plan = run.planDigest and App.db.planStore[run.planDigest]
    if not plan then return nil end
    return { plan = plan, planDigest = run.planDigest, client = run.client, build = App.Build(),
        character = run.character, now = now(App), env = App.env }
end

function App.Start(addon)
    local rec = App.db.plans[addon]
    if not rec then return nil, L["No plan is imported for %s."]:format(tostring(addon)) end
    local ctx = { plan = rec.plan, planDigest = rec.digest, client = App.Client(), build = App.Build(),
        character = App.Character(), now = now(App), env = App.env }
    local run = ns.Run.New(ctx)
    while App.db.runs[run.runId] do run.runId = run.runId .. "x" end
    App.db.runs[run.runId] = run
    App.db.currentByChar[App.Character()] = run.runId
    if App.db.ui.view then App.db.ui.view[App.Character()] = nil end
    App.db.planStore[rec.digest] = rec.plan
    App.db.ui.pendingStart = nil
    App.PruneRuns()
    App.Log("run started " .. run.runId)
    return run
end

function App.Current()
    local id = App.db and shownId()
    local run = id and App.db.runs[id]
    if not run then return nil end
    local ctx = App.Ctx(run)
    if not ctx then return nil end
    local sid = ns.Run.CurrentId(run)
    local step = sid and ns.Run.stepOf(ctx, sid)
    return run, ctx, step
end

-- What the tester can copy for this step: allowed slash commands, then macro text.
function App.Copyables(step, plan)
    local out = {}
    local a = step.action
    -- One command per box: a multi-line macro pasted as one line would change its meaning.
    local function add(text)
        for line in ((text or "") .. "\n"):gmatch("(.-)\n") do if line ~= "" then out[#out + 1] = line end end
    end
    if a.kind == "copy-slash" then add(a.text) end
    for _, c in ipairs(a.commands or {}) do add(c) end
    if a.kind == "secure-macro" then
        for _, m in ipairs(plan.macros or {}) do if m.id == a.macro then add(m.text) end end
    end
    if a.kind == "reload" then add("/reload") end
    return out
end

-- The card has this many copy boxes. A macro with more lines is not offered as one button: it would run
-- commands the tester cannot see.
App.MAX_COPY = 4

-- The macro text a secure button or the "CT" macro would run, or nil. Always re-checked against the allow list.
function App.MacroText(step, plan)
    local a = step.action
    local text
    if a.kind == "secure-macro" then
        for _, m in ipairs(plan.macros or {}) do if m.id == a.macro then text = m.text end end
    elseif a.kind == "copy-slash" then text = a.text
    elseif a.kind == "reload" then text = "/reload"
    elseif type(a.commands) == "table" and #a.commands > 0 then text = table.concat(a.commands, "\n") end -- manual step with commands: Run does them in order
    if text and ns.Plan.MacroAllowed(text, ns.Plan.SLASH[plan.addon]) then
        local lines = 0
        for line in (text .. "\n"):gmatch("(.-)\n") do if line ~= "" then lines = lines + 1 end end
        if lines <= App.MAX_COPY then return text end
    end
end

-- Section intro for the card, shown on the first step of a section that has no verdicts yet.
function App.SectionIntro(run, ctx, stepId)
    local steps = ns.Plan.Steps(ctx.plan, run.client)
    local mine
    for _, e in ipairs(steps) do if e.step.id == stepId then mine = e end end
    if not (mine and mine.intro) then return nil end
    for _, e in ipairs(steps) do
        if e.sectionId == mine.sectionId then
            local v = run.steps[e.step.id].verdict
            if v ~= "pending" then return nil end
        end
    end
    return mine.intro
end

-- True until any step has a verdict: show the plan's preamble.
function App.AtStart(run)
    for _, rec in pairs(run.steps) do
        if rec.verdict ~= "pending" and rec.verdict ~= "inapplicable" then return false end
    end
    return true
end

function App.Begin()
    local run, ctx, step = App.Current()
    if not step then return nil end
    return ns.Run.Begin(run, ctx, step.id), step
end

local function logResult(step, a)
    local why
    for _, o in ipairs(a.outcomes or {}) do if o.result ~= "pass" and not o.diagnostic then why = o.why; break end end
    App.Log(("step %s %s%s%s%s"):format(step.id, a.verdict, a.by == "auto" and " auto" or "",
        a.evidence and (" evidence " .. a.evidence) or "", why and (": " .. why) or ""))
end

function App.Verdict(verdict, note)
    local run, ctx, step = App.Current()
    if run and run.endedAt then return nil, L["This run has ended. Start the plan again for a new run."] end
    if not step then return nil, L["There is no current step."] end
    local a, err = ns.Run.Verdict(run, ctx, step.id, verdict, note)
    if a then logResult(step, a) end
    return a, err, step
end

-- Seconds until the current auto step settles itself, or nil.
function App.TimeLeft()
    local run, ctx, step = App.Current()
    if not (step and step.auto and step.timeout) then return nil end
    ctx.now = now(App)
    return ns.Run.TimeLeft(run, ctx, step.id)
end

-- The card's refresh calls this for the current step. Records a result only when the step is auto and its evidence says so.
function App.AutoSettle(note)
    local run, ctx, step = App.Current()
    if not (step and step.auto) then return nil end
    ctx.now = now(App)
    local a = ns.Run.AutoSettle(run, ctx, step.id, note)
    if a then logResult(step, a) end
    return a, step
end

-- The open attempt survived a reload: the card should ask for verification, not another reload.
function App.MarkReloaded()
    local run, ctx, step = App.Current()
    if not step then return end
    local rec = run.steps[step.id]
    local a = rec.attempts[#rec.attempts]
    if a and not a.verdict then a.reloaded = true end
end

function App.Goto(delta)
    local run = App.Current()
    if not run then return nil end
    return ns.Run.Goto(run, delta)
end

-- The run /ct end and the card's End run act on: nil plus a sentence when there is none or it already ended.
function App.CanEnd()
    local run = App.db.runs[shownId() or ""]
    if not run then return nil, L["There is no run."] end
    if run.endedAt then return nil, L["This run has already ended."] end
    return run
end

-- End the current run. runId (optional) must still be the current run: a confirmation can outlive a change of run.
function App.End(runId)
    local run, err = App.CanEnd()
    if not run then return nil, err end
    if runId and run.runId ~= runId then return nil, L["There is no run."] end
    ns.Run.End(run, now(App))
    App.Log("run ended " .. run.runId)
    return run
end

-- End the current run and forget its plan: the loaded plan and its place in the recent list go. The stored copy stays,
-- so the ended run keeps its results screen and its export. runId is checked as for App.End.
function App.ClearPlan(runId)
    local run, err = App.End(runId)
    if not run then return nil, err end
    local ui = App.db.ui
    local loaded = App.db.plans[run.addon]
    local gone = { [run.planDigest or ""] = true, [loaded and loaded.digest or ""] = true }
    App.db.plans[run.addon] = nil
    if ui.pendingStart == run.addon then ui.pendingStart = nil end
    if ui.lastImport == run.addon then ui.lastImport = nil end
    local keep = {}
    for _, e in ipairs(ui.recent or {}) do if not gone[e.digest] then keep[#keep + 1] = e end end
    ui.recent = keep
    App.PrunePlans()
    App.Log("plan cleared " .. run.addon)
    return run
end

function App.Undo()
    local run, ctx = App.Current()
    if not run then return false end
    return ns.Run.UndoLast(run, ctx)
end

function App.Export(runId)
    local run = App.db.runs[runId or shownId() or ""]
    if not run then return nil, L["There is no run."] end
    local copy = ns.Run.Export and ns.Run.Export(run) or run
    local s, err = ns.Codec.Encode(copy)
    if s then App.Log("run exported " .. run.runId) end
    return s, err
end

function App.Status()
    local run = App.db.runs[shownId() or ""]
    if not run then return L["No run."] end
    local c = ns.Run.Counts(run)
    local line = L["%s: %d pass, %d partial, %d fail, %d unverified, %d skipped, %d left, %d not for this client (revision %d, saved on reload)"]:format(
        run.runId, c.pass, c.partial, c.fail, c.unverified, c.skip, c.pending, c.inapplicable, run.revision)
    return run.endedAt and L["%s (run ended)"]:format(line) or line
end
