-- Run state machine. State lives in a plain table (saved variable); no WoW globals except via env.
local _, ns = ...
local Run = {}
ns.Run = Run

-- partial: "mostly works". It is gated by evidence like pass and moves on like pass; the report lists it with its note.
local VERDICTS = { pass = true, partial = true, fail = true, skip = true }

-- A short tag from the character name keeps run ids from two testers (two databases) apart.
function Run.Tag(s)
    local h = 5381
    for i = 1, #(s or "") do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%04x"):format(h % 65536)
end

-- ctx: { plan, client, build, character, now, env }
function Run.New(ctx)
    local steps, inapplicable = ns.Plan.Steps(ctx.plan, ctx.client)
    local run = {
        kind = "results", wtt = 1,
        runId = ("%s-%d-%s"):format(ctx.plan.addon, ctx.now, Run.Tag(ctx.character)),
        revision = 0, addon = ctx.plan.addon, planDigest = ctx.planDigest, planTitle = ctx.plan.title,
        client = ctx.client, build = ctx.build, character = ctx.character,
        started = ctx.now, order = {}, steps = {}, current = 1,
    }
    for i, e in ipairs(steps) do
        run.order[i] = e.step.id
        run.steps[e.step.id] = { attempts = {}, verdict = "pending" }
    end
    for _, e in ipairs(inapplicable) do run.steps[e.step.id] = { attempts = {}, verdict = "inapplicable" } end
    return run
end

function Run.Touch(run, now) run.revision = run.revision + 1; run.updated = now end

local function stepOf(ctx, id)
    for _, sec in ipairs(ctx.plan.sections) do
        for _, st in ipairs(sec.steps) do if st.id == id then return st end end
    end
end
Run.stepOf = stepOf

-- Which requirements are unmet right now? Requirement = { text=, probe= } with an optional state probe.
function Run.Blocked(ctx, step)
    local missing = {}
    for _, r in ipairs(step.requires or {}) do
        local def = ctx.plan.requirements and ctx.plan.requirements[r]
        if def and def.probe then
            local op, value = def.op, def.value
            if op == nil then -- addon-loaded answers true or false, so "exists" would pass for an unloaded addon
                if def.probe == "addon-loaded" then op, value = "eq", true else op = "exists" end
            end
            local a = { kind = "state", probe = def.probe, name = def.name, path = def.path, op = op, value = value }
            if ns.Evidence.CheckState(a, ctx.env) ~= "pass" then missing[#missing + 1] = def.text or r end
        end
    end
    return missing
end

-- Open an attempt: snapshot logs first so the player can act straight away.
function Run.Begin(run, ctx, id)
    local rec = run.steps[id]
    local last = rec.attempts[#rec.attempts]
    if last and not last.verdict then return last end -- already open (e.g. after a reload)
    local a = { n = #rec.attempts + 1, started = ctx.now, snapshots = ns.Evidence.Snapshot(ctx.plan, ctx.env), build = ctx.build }
    -- After the runner settled the last attempt as unverified, the retry waits for the player: no loop of automatic results.
    -- (Undo resets the step to pending: that is the player acting, so the retry may settle itself.)
    if last and last.by == "auto" and last.verdict == "unverified" and rec.verdict == "unverified" then a.noauto = true end
    rec.attempts[#rec.attempts + 1] = a
    run.current = Run.IndexOf(run, id)
    Run.Touch(run, ctx.now)
    return a
end

-- A step is open until it has a result; one stuck on missing evidence (unverified) is still open.
local function isOpen(run, n)
    local v = run.steps[run.order[n]].verdict
    return v == "pending" or v == "unverified"
end

-- Index of the first open step after position `from`, else the first open step anywhere, else nil.
function Run.NextPending(run, from)
    for n = from + 1, #run.order do if isOpen(run, n) then return n end end
    for n = 1, from do if isOpen(run, n) then return n end end
end

-- Move the viewed step back or forth. The results screen (one past the last step) is reachable only when nothing is pending.
function Run.Goto(run, delta)
    local last = Run.NextPending(run, 0) and #run.order or (#run.order + 1)
    run.current = math.max(1, math.min(last, run.current + delta))
    return run.current
end

-- Live checks of the current attempt for the card.
function Run.Preview(run, ctx, id)
    local step, rec = stepOf(ctx, id), run.steps[id]
    if not (step and rec) then return {} end
    local a = rec.attempts[#rec.attempts]
    return ns.Evidence.Preview(step, a and not a.verdict and a.snapshots or nil, ctx.plan, ctx.env)
end

function Run.IndexOf(run, id)
    for i, v in ipairs(run.order) do if v == id then return i end end
end

-- Auto steps: when every required check is met, or the timeout has passed, record a pass claim through the same gate
-- as a player's click. The gate turns it into fail (contradicting evidence) or unverified (missing evidence) at the timeout.
-- Reads only; the card calls it from its refresh. Returns the attempt when it recorded a result.
function Run.AutoSettle(run, ctx, id, note)
    local step, rec = stepOf(ctx, id), run.steps[id]
    if not (step and step.auto and rec) then return nil end
    local a = rec.attempts[#rec.attempts]
    if not a or a.verdict or a.noauto then return nil end
    local allMet = true
    local items = ns.Evidence.Preview(step, a.snapshots, ctx.plan, ctx.env)
    for _, it in ipairs(items) do if it.state ~= "met" then allMet = false end end
    local due = step.timeout and (ctx.now - a.started) >= step.timeout
    if due then return Run.Verdict(run, ctx, id, "pass", note, "auto") end
    -- A step that asks for a reload is not settled before the reload happened. The recording read must agree with the
    -- live read: a check that flipped in between is left for the next refresh, never recorded as a failure.
    local waitingReload = step.reload == "after_action" and not a.reloaded
    if allMet and #items > 0 and not waitingReload then return Run.Verdict(run, ctx, id, "pass", note, "auto", true) end
end

-- Seconds until an auto step with a timeout settles, counted from when its attempt opened; nil when none applies.
function Run.TimeLeft(run, ctx, id)
    local step, rec = stepOf(ctx, id), run.steps[id]
    if not (step and step.auto and step.timeout and rec) then return nil end
    local a = rec.attempts[#rec.attempts]
    if not a or a.verdict or a.noauto then return nil end
    return math.max(0, step.timeout - (ctx.now - a.started))
end

-- Evaluate assertions and record the verdict. Returns the attempt. `by` = "auto" marks a result the runner recorded.
function Run.Verdict(run, ctx, id, verdict, note, by, holdUnlessMet)
    if not VERDICTS[verdict] then return nil, "bad verdict" end
    local step = stepOf(ctx, id)
    local rec = run.steps[id]
    if not step or not rec then return nil, "unknown step" end
    local a = rec.attempts[#rec.attempts]
    if not a or a.verdict then a = Run.Begin(run, ctx, id) end
    a.outcomes = {}
    local anyFail, anyUnverified, required = false, false, 0
    if verdict ~= "skip" then
        for i, as in ipairs(step.assertions or {}) do
            local r, why = ns.Evidence.Check(as, a.snapshots, ctx.plan, ctx.env)
            a.outcomes[i] = { result = r, why = why, diagnostic = as.diagnostic or nil }
            if not as.diagnostic then
                required = required + 1
                if r == "fail" then anyFail = true elseif r == "unverified" then anyUnverified = true end
            end
        end
    end
    if holdUnlessMet and (anyFail or anyUnverified) then a.outcomes = nil; return nil end
    -- A pass needs every required assertion to match. Contradicting evidence fails; missing evidence is unverified.
    local needsAssert = false
    for _, v in ipairs(step.verify) do if v == "assertions" then needsAssert = true end end
    local effective = verdict
    if (verdict == "pass" or verdict == "partial") and needsAssert then
        if anyFail then effective, a.evidence = "fail", "contradicts"
        elseif anyUnverified then effective, a.evidence = "unverified", "unverified"
        elseif required > 0 then a.evidence = "matched"
        else a.evidence = "diagnostic-only" end
    end
    a.claimed, a.by = verdict, by
    a.verdict, a.note, a.finished = effective, note, ctx.now
    a.snapshots = nil
    verdict = effective
    rec.verdict = verdict
    rec.evidence = a.evidence
    run.history = run.history or {}
    run.history[#run.history + 1] = id
    -- Fail moves on like the other results (Undo retries it). Only missing evidence keeps the step open.
    if verdict ~= "unverified" then
        run.current = Run.NextPending(run, Run.IndexOf(run, id)) or (#run.order + 1)
    end
    Run.Touch(run, ctx.now)
    return a
end

-- Undo the last verdict of a step, reopening it.
function Run.Undo(run, ctx, id)
    local rec = run.steps[id]
    local a = rec and rec.attempts[#rec.attempts]
    if not a or not a.verdict then return false end
    table.remove(rec.attempts)
    local prev = rec.attempts[#rec.attempts]
    rec.verdict = prev and prev.verdict or "pending"
    rec.evidence = prev and prev.evidence or nil
    if rec.verdict ~= "pending" then rec.verdict = "pending" end
    run.current = Run.IndexOf(run, id)
    Run.Touch(run, ctx.now)
    return true
end

-- A copy for export: open-attempt snapshots are bulky bookkeeping and stay behind.
function Run.Export(run)
    local function copy(v)
        if type(v) ~= "table" then return v end
        local o = {}
        for k, x in pairs(v) do o[k] = copy(x) end
        return o
    end
    local out = copy(run)
    -- Only the attempt records carry snapshots; a step may legitimately be named "snapshots".
    for _, rec in pairs(out.steps or {}) do
        for _, a in ipairs(rec.attempts or {}) do a.snapshots = nil end
    end
    return out
end

-- Undo the most recent verdict in commit order, dropping any retry attempt opened after it.
function Run.UndoLast(run, ctx)
    local h = run.history or {}
    local id = table.remove(h)
    if not id then return false end
    local rec = run.steps[id]
    local last = rec.attempts[#rec.attempts]
    if last and not last.verdict then table.remove(rec.attempts) end
    return Run.Undo(run, ctx, id), id
end

function Run.Counts(run)
    local c = { pass = 0, partial = 0, fail = 0, skip = 0, unverified = 0, pending = 0, inapplicable = 0 }
    for _, rec in pairs(run.steps) do c[rec.verdict] = (c[rec.verdict] or 0) + 1 end
    c.open = c.pending + c.unverified
    return c
end

function Run.CurrentId(run) return run.order[run.current] end
