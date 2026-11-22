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
    App.db = db
    if ns.Log then
        ns.Log.Bind(db.log, (opts and opts.debug) or function() return db.log.enabled end, function() return now(App) end)
    end
    return db
end

function App.Log(msg)
    if ns.Log then ns.Log.Record("wtt", msg) end
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
    if err:find("version") then return L["This string needs a newer TestThat."] end
    if err:find("not a WTT") then return L["This is not a TestThat string."] end
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

-- Import a pasted string. Returns plan table or nil + error text. Nothing is stored on failure.
function App.ImportPlan(str)
    local tbl, err, digest = ns.Codec.Decode(str)
    if not tbl then App.Log("import failed: " .. tostring(err)); return nil, L["The string could not be read. %s"]:format(readError(err)) end
    if tbl.kind ~= "plan" then return nil, L["This string holds %s, not a plan."]:format(tostring(tbl.kind)) end
    local errs = ns.Plan.Validate(tbl)
    if #errs > 0 then
        App.Log("import rejected: " .. errs[1])
        return nil, L["The plan is not valid (%d problems). First: %s"]:format(#errs, errs[1])
    end
    App.db.plans[tbl.addon] = { plan = tbl, digest = digest }
    App.db.planStore[digest] = tbl -- runs keep the exact plan they started with
    App.RememberRecent(tbl, digest)
    App.db.ui.pendingStart = tbl.addon -- a new plan takes focus: the card offers Start run, even after a finished run
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
    App.db.planStore[rec.digest] = rec.plan
    App.db.ui.pendingStart = nil
    App.Log("run started " .. run.runId)
    return run
end

function App.Current()
    local id = App.db and App.db.currentByChar[App.Character()]
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

-- The macro text a secure button or the "WTT" macro would run, or nil. Always re-checked against the allow list.
function App.MacroText(step, plan)
    local a = step.action
    local text
    if a.kind == "secure-macro" then
        for _, m in ipairs(plan.macros or {}) do if m.id == a.macro then text = m.text end end
    elseif a.kind == "copy-slash" then text = a.text
    elseif a.kind == "reload" then text = "/reload"
    elseif type(a.commands) == "table" and #a.commands > 0 then text = table.concat(a.commands, "\n") end -- manual step with commands: Run does them in order
    if text and ns.Plan.MacroAllowed(text, ns.Plan.SLASH[plan.addon]) then return text end
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

function App.Verdict(verdict, note)
    local run, ctx, step = App.Current()
    if not step then return nil, L["There is no current step."] end
    local a, err = ns.Run.Verdict(run, ctx, step.id, verdict, note)
    if a then
        local why
        for _, o in ipairs(a.outcomes or {}) do if o.result ~= "pass" and not o.diagnostic then why = o.why; break end end
        App.Log(("step %s %s%s%s"):format(step.id, a.verdict, a.evidence and (" evidence " .. a.evidence) or "", why and (": " .. why) or ""))
    end
    return a, err, step
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

function App.Undo()
    local run, ctx = App.Current()
    if not run then return false end
    return ns.Run.UndoLast(run, ctx)
end

function App.Export(runId)
    local run = App.db.runs[runId or App.db.currentByChar[App.Character()] or ""]
    if not run then return nil, L["There is no run."] end
    local copy = ns.Run.Export and ns.Run.Export(run) or run
    return ns.Codec.Encode(copy)
end

function App.Status()
    local run = App.db.runs[App.db.currentByChar[App.Character()] or ""]
    if not run then return L["No run."] end
    local c = ns.Run.Counts(run)
    return L["%s: %d pass, %d partial, %d fail, %d unverified, %d skipped, %d left, %d not for this client (revision %d, saved on reload)"]:format(
        run.runId, c.pass, c.partial, c.fail, c.unverified, c.skip, c.pending, c.inapplicable, run.revision)
end
