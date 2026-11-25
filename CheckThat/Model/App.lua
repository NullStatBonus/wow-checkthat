-- Application logic: import, runs, verdicts, export. Testable with a fake env; no frames here.
local _, ns = ...
local L = ns.L
local App = { db = nil, env = _G }
ns.App = App

local function now(self) return (self.env.time and self.env.time()) or 0 end

-- db is the saved global table. opts.debug() says whether recording is on (default: db.log.enabled).
-- A run saved in a newer major format is kept aside, untouched: this version cannot read it right, and a pass over it
-- (normalizing, touching, pruning, counting) could damage it. Every other part of the addon then never sees it. It moves back
-- when a CheckThat that reads its format loads it.
function App.SplitFuture(db)
    for id, run in pairs(db.runs) do
        if ns.Run.Opaque(run) then
            db.future = db.future or {}
            if db.future[id] == nil then
                db.future[id], db.runs[id] = run, nil
                -- Which plan it needs is unknown, so the plans stored now stay. Plans imported later can still go.
                if type(run.planDigest) ~= "string" then
                    db.futureKeep = db.futureKeep or {}
                    for digest in pairs(db.planStore or {}) do db.futureKeep[digest] = true end
                end
            end -- else an entry with that id is already aside: both stay where they are
        end
    end
    for id, run in pairs(db.future or {}) do
        if not ns.Run.Opaque(run) and db.runs[id] == nil then db.runs[id], db.future[id] = run, nil end -- never over a readable run
    end
    if db.future and next(db.future) == nil then db.future, db.futureKeep = nil, nil end
end

function App.FutureCount()
    local n = 0
    for _ in pairs(App.db and App.db.future or {}) do n = n + 1 end
    return n
end

function App.Init(db, env, opts)
    App.env = env or _G
    db.plans = db.plans or {}
    db.planStore = db.planStore or {}
    db.currentByChar = db.currentByChar or {}
    db.runs = db.runs or {}
    App.SplitFuture(db)
    db.log = db.log or { entries = {} }
    db.ui = db.ui or {}
    db.ui.shareReload = nil -- a reload request lasts until the next load
    db.facts = db.facts or {}
    db.errors = db.errors or {}
    db.errorStacks = db.errorStacks or {}
    App.db = db
    -- Facts and errors belong to the character's open run, also while the card shows another run.
    local function runOpen()
        local run = App.db.runs[App.db.currentByChar[App.Character()] or ""]
        return run ~= nil and not run.endedAt
    end
    if ns.Facts then ns.Facts.Bind(db.facts, function() return now(App) end, runOpen) end
    if ns.Errors then
        ns.Errors.Bind(db.errors, function() return now(App) end, runOpen, App.env, db.errorStacks)
    end
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
    for _, r in pairs(App.db.future or {}) do
        if type(r.planDigest) == "string" then keep[r.planDigest] = true end
    end
    for digest in pairs(App.db.futureKeep or {}) do keep[digest] = true end -- a run that names no plan may need one stored when it was set aside
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
    local fmt = run.endedAt and L["%s  %s (%s): %d pass, %d fail, %d open, ended"] or L["%s  %s (%s): %d pass, %d fail, %d open"]
    return fmt:format(when, tostring(run.planTitle or run.addon), tostring(run.character), c.pass, c.fail, c.open)
end

-- A short row for the Runs dropdown: the pull-out grows with its longest row, so the text stays narrow.
local function rowText(run)
    local c = ns.Run.Counts(run)
    local when = run.started and App.env.date and App.env.date("%m-%d %H:%M", run.started) or tostring(run.started or "?")
    local title = tostring(run.planTitle or run.addon)
    if #title > 24 then title = title:sub(1, 24):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
    local fmt = run.endedAt and L["%s  %s (%s): %d/%d/%d, ended"] or L["%s  %s (%s): %d/%d/%d"]
    return fmt:format(when, title, tostring(run.character):match("^[^-]+") or "?", c.pass, c.fail, c.open)
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
        out[#out + 1] = { id = e.id, ended = e.run.endedAt ~= nil, character = e.run.character, current = e.id == cur, text = rowText(e.run) }
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
    ns.Run.Normalize(run, plan, run.client)
    return { plan = plan, planDigest = run.planDigest, client = run.client, build = App.Build(),
        character = run.character, now = now(App), env = App.env }
end

-- The categories of a plan with how many steps each has for this client: { { id, title, steps } }.
function App.CategoryChoices(plan)
    local out, byId = {}, {}
    for _, c in ipairs((ns.Plan.Categories(plan))) do
        byId[c.id] = { id = c.id, title = c.title, steps = 0 }
        out[#out + 1] = byId[c.id]
    end
    for _, e in ipairs((ns.Plan.Steps(plan, App.Client()))) do
        local c = byId[e.category]
        if c then c.steps = c.steps + 1 end
    end
    return out
end

-- The categories the tester can pick for the next run of a plan, in plan order: { id, title, steps, picked }.
-- Every category starts picked; only the ones the tester cleared are remembered.
function App.Picks(addon)
    local rec = App.db.plans[addon or ""]
    if not rec then return {} end
    local off = App.db.ui.cleared and App.db.ui.cleared[addon] or {}
    local out = App.CategoryChoices(rec.plan)
    for _, c in ipairs(out) do c.picked = not off[c.id] end
    return out
end

function App.SetPick(addon, id, on)
    App.db.ui.cleared = App.db.ui.cleared or {}
    local off = App.db.ui.cleared[addon] or {}
    off[id] = (not on) or nil
    App.db.ui.cleared[addon] = next(off) and off or nil
end

-- The ids to start a run with, or nil when the plan has one category (no choice to make).
function App.PickedIds(addon)
    local list = App.Picks(addon)
    if #list < 2 then return nil end
    local ids = {}
    for _, c in ipairs(list) do if c.picked and c.steps > 0 then ids[#ids + 1] = c.id end end
    return ids
end

-- picks is a list of category ids, or nil to run every category.
function App.Start(addon, picks)
    local rec = App.db.plans[addon]
    if not rec then return nil, L["No plan is imported for %s."]:format(tostring(addon)) end
    local known = {}
    for _, c in ipairs((ns.Plan.Categories(rec.plan))) do known[c.id] = true end
    for _, id in ipairs(picks or {}) do
        if not known[id] then return nil, L["There is no category called %s."]:format(ns.Slash.Esc(id)) end
    end
    local ctx = { plan = rec.plan, planDigest = rec.digest, client = App.Client(), build = App.Build(),
        character = App.Character(), now = now(App), env = App.env, selected = picks }
    local run = ns.Run.New(ctx)
    if not run then return nil, picks and L["Pick at least one category that has steps for this client."] or L["The plan has no steps for this client."] end
    if ns.Errors then ns.Errors.Hook(); ns.Errors.Rebase() end
    while App.db.runs[run.runId] or (App.db.future and App.db.future[run.runId]) do run.runId = run.runId .. "x" end
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

-- Run.Begin or Run.Verdict, then ask for an error stack when the call opened a new attempt: an open one has its own.
local function opening(run, step, fn)
    local rec = run.steps[step.id]
    local before = rec and #rec.attempts
    local a, err = fn()
    if ns.Errors and rec and #rec.attempts ~= before then ns.Errors.StepStarted() end
    return a, err
end

function App.Begin()
    local run, ctx, step = App.Current()
    if not step then return nil end
    if ns.Errors then ns.Errors.Watch(); ns.Errors.Sample() end
    local a = opening(run, step, function() return ns.Run.Begin(run, ctx, step.id) end)
    return a, step
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
    if ns.Errors then
        local rec = run.steps[step.id]
        local last = rec and rec.attempts[#rec.attempts]
        if not last or last.verdict then ns.Errors.StepStarted() end -- this verdict opens its own attempt: arm before the errors are read
        ns.Errors.Watch(); ns.Errors.Sample(); ns.Errors.Check()
    end
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
    if ns.Errors then ns.Errors.Watch(); ns.Errors.Sample(); ns.Errors.Check() end
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

-- The words for category states: color is never the only signal.
function App.StateWord(state, counts)
    if state == "red" then return L["failed"] elseif state == "yellow" then return L["partial or unverified"]
    elseif state == "green" then return L["passed"] elseif state == "off" then return L["not picked"] end
    local resolved = counts and counts.resolved or 0
    if state == "blue" then return resolved > 0 and L["in progress"] or L["untested"] end
    return resolved > 0 and L["all skipped"] or L["no steps"]
end

-- Rows for the tracker, the Home list and /ct categories of the run on the card:
-- { id, title, state, counts, picked }, and the overall state with its counts.
function App.Categories()
    local run = App.db.runs[shownId() or ""]
    if not (run and run.categories) then return nil end
    local rows = {}
    for _, c in ipairs(run.categories) do
        local state, counts = ns.Run.CategoryState(run, c.id)
        rows[#rows + 1] = { id = c.id, title = c.title, state = state, counts = counts, picked = run.selected[c.id] == true }
    end
    local overall, total = ns.Run.OverallState(run)
    return rows, overall, total, run
end

-- One line for /ct categories and the Home list. The id is what /ct run and /ct rerun take.
-- The result in words for the caption: it names the count behind red and yellow.
function App.StatePhrase(state, c)
    if state == "red" then return L["%d failed"]:format(c.fail or 0) end
    if state == "yellow" then
        local p, u = c.partial or 0, c.unverified or 0
        if p > 0 and u > 0 then return L["%d partial, %d unverified"]:format(p, u) end
        if p > 0 then return L["%d partial"]:format(p) end
        return L["%d unverified"]:format(u)
    end
    return App.StateWord(state, c)
end

function App.CategoryLine(row)
    if not row.picked then return L["%s (%s): not picked"]:format(row.title, row.id) end
    local c = row.counts
    return L["%s (%s): %s, %d passed, %d failed, %d open"]:format(row.title, row.id, App.StateWord(row.state, c), c.pass, c.fail, c.open)
end

-- The state word and what happened to the steps, for a row of the Categories window.
function App.RowDetail(row)
    if not row.picked then return App.StateWord(row.state, row.counts) end
    local c = row.counts
    return L["%s · %d passed, %d failed, %d open"]:format(App.StateWord(row.state, c), c.pass, c.fail, c.open)
end

-- The steps of one category in plan order, also the ones that are not picked or not for this client, for the Categories window:
-- { id, title, verdict, word, offered }. A step that is not offered is listed but cannot be shown.
local STEP_WORD = {
    pass = L["passed"], fail = L["failed"], partial = L["partial"], unverified = L["unverified"], skip = L["skipped"],
    pending = L["open"], inapplicable = L["not for this client"], deselected = L["not picked"],
}
function App.CategorySteps(id)
    local run, ctx = App.Current()
    if not run then return {} end
    local out = {}
    for _, sec in ipairs(ctx.plan.sections) do
        for _, st in ipairs(sec.steps) do
            if run.cat[st.id] == id then
                local rec = run.steps[st.id]
                local v = rec and rec.verdict or "pending"
                out[#out + 1] = { id = st.id, title = st.title, verdict = v, word = STEP_WORD[v] or v, offered = v ~= "deselected" and v ~= "inapplicable" }
            end
        end
    end
    return out
end

-- Show one step on the card (a click on a step row). Only a step id counts, never a category name. Returns true, or nil and text.
function App.ShowStep(id)
    local run, ctx = App.Current()
    if not run then return nil, L["There is no run."] end
    local ok = ns.Run.Show(run, ctx, id)
    if not ok then return nil, L["That step is not in this run."] end
    App.Log("show step " .. tostring(id))
    return true
end

-- The run the player can change: the one on the card, when it has not ended.
local function activeRun()
    local run, ctx = App.Current()
    if not run then return nil, nil, L["There is no run."] end
    if run.endedAt then return nil, nil, L["This run has ended."] end
    return run, ctx
end

local function name(run, id)
    local c = ns.Run.CategoryOf(run, id)
    return ns.Slash.Esc(c and c.title or id)
end

-- Show a category (its first open step, picking the category first) or a step. Returns kind, step id, or nil and text.
function App.Trigger(what)
    local run, ctx, err = activeRun()
    if not run then return nil, err end
    if ns.Errors then ns.Errors.Hook() end
    local kind, id = ns.Run.Trigger(run, ctx, what)
    if not kind then
        local key = tostring(what or ""):lower()
        if id == "done" then return nil, L["Every step in %s has a result. Use /ct rerun %s to run them again."]:format(name(run, key), ns.Slash.Esc(key)) end
        if id == "ambiguous" then return nil, L["The name %s is both a category and a step, so nothing changed. Use the other name."]:format(ns.Slash.Esc(what or "")) end
        if id == "not for this client" then return nil, L["That step is not for this client."] end
        return nil, L["There is no category or step called %s."]:format(ns.Slash.Esc(what or ""))
    end
    App.Log(("trigger %s %s: step %s"):format(kind, tostring(what):lower(), id))
    return kind, id
end

-- Pick a category and leave the viewed step as it is. Returns true, false when it was already picked, or nil and text.
function App.Select(what)
    local run, ctx, err = activeRun()
    if not run then return nil, err end
    local key = tostring(what or ""):lower()
    local ok, why = ns.Run.Select(run, ctx, key)
    if ok == nil then return nil, L["There is no category called %s."]:format(ns.Slash.Esc(what or "")) end
    if ok then App.Log("select " .. key) end
    return ok
end

-- Can the category leave the run now? The card menu shows Remove from run only then.
-- The menu passes the exact id; a typed name is lower case, so ids that differ only in case stay apart.
local function categoryKey(run, what)
    what = tostring(what or "")
    return ns.Run.CategoryOf(run, what) and what or what:lower()
end

function App.CanDeselect(what)
    local run = App.Current()
    return run ~= nil and ns.Run.DeselectBlock(run, categoryKey(run, what)) == nil
end

-- Take a category out of the run. Returns true, or nil and text.
function App.Deselect(what)
    local run, ctx, err = activeRun()
    if not run then return nil, err end
    local key = categoryKey(run, what)
    local ok, why = ns.Run.Deselect(run, ctx, key)
    if ok then App.Log("deselect " .. key); return true end
    if why == "unknown category" then return nil, L["There is no category called %s."]:format(ns.Slash.Esc(what or "")) end
    if why == "not picked" then return nil, L["%s is not part of this run. Use /ct run %s to add it."]:format(name(run, key), ns.Slash.Esc(key)) end
    if why == "has results" then return nil, L["%s has results, so it stays in the run."]:format(name(run, key)) end
    return nil, L["A run needs at least one category."]
end

-- How many steps a rerun would reopen: the picked steps of the category that have a result.
function App.RerunCount(what)
    local run, _, err = activeRun()
    if not run then return nil, err end
    local key = tostring(what or ""):lower()
    if key == ns.Run.FAILED and not ns.Run.CategoryOf(run, key) then
        local n = 0
        for _, sid in ipairs(run.order) do
            local v = run.steps[sid].verdict
            if v == "fail" or v == "unverified" then n = n + 1 end
        end
        return n, L["failed and unverified steps"]
    end
    if not ns.Run.CategoryOf(run, key) then return nil, L["There is no category called %s."]:format(ns.Slash.Esc(what or "")) end
    if not run.selected[key] then return nil, L["%s is not part of this run. Use /ct run %s to add it."]:format(name(run, key), ns.Slash.Esc(key)) end
    local n = 0
    for _, sid in ipairs(run.order) do
        if run.cat[sid] == key and run.steps[sid].verdict ~= "pending" then n = n + 1 end
    end
    return n, name(run, key)
end

-- What to say when a rerun has nothing to reopen.
function App.NothingToReopen(what, title)
    if tostring(what or ""):lower() == ns.Run.FAILED and title == L["failed and unverified steps"] then return L["No step has failed or is unverified."] end
    return L["Nothing to reopen in %s: no step has a result."]:format(title)
end

-- Reopen the picked steps of a category. Returns how many steps reopened, or nil and text.
function App.Rerun(what)
    local run, ctx, err = activeRun()
    if not run then return nil, err end
    local key = tostring(what or ""):lower()
    local n, why = ns.Run.Rerun(run, ctx, what)
    if not n then
        if why == "not picked" then return nil, L["%s is not part of this run. Use /ct run %s to add it."]:format(name(run, key), ns.Slash.Esc(key)) end
        return nil, L["There is no category called %s."]:format(ns.Slash.Esc(what or ""))
    end
    App.Log(("rerun %s: %d steps reopened"):format(key, n))
    return n, (key == ns.Run.FAILED and not ns.Run.CategoryOf(run, key)) and L["failed and unverified steps"] or name(run, key)
end

function App.Status()
    local run = App.db.runs[shownId() or ""]
    if not run then return L["No run."] end
    local c = ns.Run.Counts(run)
    local line = L["%s: %d pass, %d partial, %d fail, %d unverified, %d skipped, %d left, %d not for this client (revision %d, saved on reload)"]:format(
        run.runId, c.pass, c.partial, c.fail, c.unverified, c.skip, c.pending, c.inapplicable, run.revision)
    if c.deselected > 0 then line = L["%s, %d not picked"]:format(line, c.deselected) end
    return run.endedAt and L["%s (run ended)"]:format(line) or line
end
