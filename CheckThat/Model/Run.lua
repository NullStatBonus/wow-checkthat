-- Run state machine. State lives in a plain table (saved variable); no WoW globals except via env.
local _, ns = ...
local Run = {}
ns.Run = Run

-- partial: "mostly works". It is gated by evidence like pass and moves on like pass; the report lists it with its note.
local VERDICTS = { pass = true, partial = true, fail = true, skip = true }
-- A step the tester did not pick (deselected) or that is not for this client (inapplicable) has no place in the order.
local OUT = { deselected = true, inapplicable = true }

-- A short tag from the character name keeps run ids from two testers (two databases) apart.
function Run.Tag(s)
    local h = 5381
    for i = 1, #(s or "") do h = (h * 33 + s:byte(i)) % 4294967296 end
    return ("%04x"):format(h % 65536)
end

-- The format of the saved run record (docs/results-format.md). MAJOR is the `ct` key: it rises only for a change that breaks a
-- reader (a key removed, renamed or given another meaning), and a CheckThat that knows an older major leaves such a run alone.
-- FORMAT_REV rises with every additive change (a new optional key). It only ever goes up on a run.
Run.MAJOR, Run.FORMAT_REV = 1, 3

-- An absent ct is a run from before it was kept. Any present ct that is not a whole number from 1 up to MAJOR is a run this version
-- cannot read: a higher major, but also a text, a fraction or a table, which a writer that knows more may use.
function Run.Opaque(run)
    if type(run) ~= "table" or run.ct == nil then return false end
    local c = run.ct
    if type(c) ~= "number" or c ~= c or c % 1 ~= 0 or c < 1 then return true end
    return c > Run.MAJOR
end

-- Says which format and which CheckThat wrote the latest content of a run.
local function stamp(run)
    if (run.formatRev or 0) < Run.FORMAT_REV then run.formatRev = Run.FORMAT_REV end
    local v = ns.version
    if type(v) == "string" and v ~= "" and v ~= "unknown" then run.writerVersion = v end
end

-- ctx: { plan, client, build, character, now, env, selected }
-- selected is a list of category ids to run, or nil for every category. Returns nil and a reason when no step is left.
function Run.New(ctx)
    local steps, inapplicable = ns.Plan.Steps(ctx.plan, ctx.client)
    local cats = ns.Plan.Categories(ctx.plan)
    local picked = {}
    if ctx.selected == nil then
        for _, c in ipairs(cats) do picked[c.id] = true end
    else
        for _, id in ipairs(ctx.selected) do picked[id] = true end
    end
    local run = {
        kind = "results", ct = 1,
        runId = ("%s-%d-%s"):format(ctx.plan.addon, ctx.now, Run.Tag(ctx.character)),
        revision = 0, addon = ctx.plan.addon, planDigest = ctx.planDigest, planTitle = ctx.plan.title,
        client = ctx.client, build = ctx.build, character = ctx.character,
        started = ctx.now, order = {}, steps = {}, current = 1,
        categories = {}, cat = {}, selected = {},
    }
    -- The tested addon's version, when the game could say (omitted otherwise, never "unknown").
    local tv = ctx.targetVersion
    if type(tv) == "string" and tv ~= "" and tv ~= "unknown" then run.targetVersion = tv end
    for _, c in ipairs(cats) do
        run.categories[#run.categories + 1] = { id = c.id, title = c.title }
        if picked[c.id] then run.selected[c.id] = true end
    end
    for _, e in ipairs(steps) do
        run.cat[e.step.id] = e.category
        if run.selected[e.category] then
            run.order[#run.order + 1] = e.step.id
            run.steps[e.step.id] = { attempts = {}, verdict = "pending" }
        else
            run.steps[e.step.id] = { attempts = {}, verdict = "deselected" }
        end
    end
    for _, e in ipairs(inapplicable) do
        run.cat[e.step.id] = e.category
        run.steps[e.step.id] = { attempts = {}, verdict = "inapplicable" }
    end
    if #run.order == 0 then return nil, "no steps" end
    stamp(run)
    return run
end

-- A run saved before categories holds none: each section is a category and every one was picked.
function Run.Normalize(run, plan, client)
    if run.categories then return run end
    local cats = ns.Plan.Categories(plan)
    run.revision = (run.revision or 0) + 1 -- the content changes, so a copy collected before is not the same revision
    stamp(run)
    run.categories, run.cat, run.selected = {}, {}, {}
    for _, c in ipairs(cats) do
        run.categories[#run.categories + 1] = { id = c.id, title = c.title }
        run.selected[c.id] = true
    end
    local steps, skipped = ns.Plan.Steps(plan, client)
    for _, e in ipairs(steps) do run.cat[e.step.id] = e.category end
    for _, e in ipairs(skipped) do run.cat[e.step.id] = e.category end
    return run
end

local function categoryOf(run, id)
    for _, c in ipairs(run.categories or {}) do if c.id == id then return c end end
end
Run.CategoryOf = categoryOf

-- Counts of the picked steps of one category.
local function tally(run, id)
    local c = { pass = 0, partial = 0, fail = 0, skip = 0, unverified = 0, pending = 0, total = 0 }
    for sid, cat in pairs(run.cat or {}) do
        local rec = run.steps[sid]
        if cat == id and rec and not OUT[rec.verdict] then
            c[rec.verdict] = (c[rec.verdict] or 0) + 1
            c.total = c.total + 1
        end
    end
    c.resolved = c.pass + c.partial + c.fail + c.skip
    c.open = c.pending + c.unverified
    return c
end

-- red: a step failed. yellow: a partial or unverified step. green: nothing open and one pass. blue: steps still
-- untested (none run yet, or some run and some left). Else grey (only skips, or no steps).
local function rule(c)
    if c.fail > 0 then return "red" end
    if c.partial > 0 or c.unverified > 0 then return "yellow" end
    if c.open == 0 and c.pass > 0 then return "green" end
    if c.open > 0 then return "blue" end
    return "grey"
end
Run.Rule = rule

-- State of one category: "red", "yellow", "green", "blue", "grey", or "off" when the tester did not pick it. And its counts.
function Run.CategoryState(run, id)
    local c = tally(run, id)
    if not (run.selected and run.selected[id]) then return "off", c end
    return rule(c), c
end

-- The same rule over every picked step.
function Run.OverallState(run)
    local sum = { pass = 0, partial = 0, fail = 0, skip = 0, unverified = 0, pending = 0, total = 0 }
    for _, cat in ipairs(run.categories or {}) do
        if run.selected and run.selected[cat.id] then
            local c = tally(run, cat.id)
            for k in pairs(sum) do sum[k] = sum[k] + c[k] end
        end
    end
    sum.resolved = sum.pass + sum.partial + sum.fail + sum.skip
    sum.open = sum.pending + sum.unverified
    return rule(sum), sum
end

-- Rebuild the order of the picked steps in plan order. The viewed step stays viewed.
local function reorder(run, ctx)
    local viewing = run.order[run.current]
    local wasEnd = run.current > #run.order
    run.order = {}
    for _, e in ipairs((ns.Plan.Steps(ctx.plan, ctx.client))) do
        local rec = run.steps[e.step.id]
        if rec and not OUT[rec.verdict] then run.order[#run.order + 1] = e.step.id end
    end
    local at = viewing and Run.IndexOf(run, viewing)
    run.current = at or (wasEnd and Run.NextPending(run, 0)) or math.min(run.current, #run.order + 1)
end

-- Pick a category that was not picked. Returns true, or nil and a reason.
function Run.Select(run, ctx, id)
    if run.endedAt then return nil, "run ended" end
    if not categoryOf(run, id) then return nil, "unknown category" end
    if run.selected[id] then return false end
    run.selected[id] = true
    for sid, cat in pairs(run.cat) do
        local rec = run.steps[sid]
        if cat == id and rec.verdict == "deselected" then rec.verdict = "pending" end
    end
    reorder(run, ctx)
    Run.Touch(run, ctx.now)
    return true
end

-- Why a picked category cannot leave the run, or nil: "run ended", "unknown category", "not picked", "has results", "last category".
function Run.DeselectBlock(run, id)
    if run.endedAt then return "run ended" end
    if not categoryOf(run, id) then return "unknown category" end
    if not run.selected[id] then return "not picked" end
    local others = 0 -- steps that stay in the run
    for _, sid in ipairs(run.order) do if run.cat[sid] ~= id then others = others + 1 end end
    if others == 0 then return "last category" end
    for sid, cat in pairs(run.cat) do
        local rec = run.steps[sid]
        if cat == id and rec and not OUT[rec.verdict] then
            if rec.verdict ~= "pending" then return "has results" end
            for _, a in ipairs(rec.attempts) do if a.verdict then return "has results" end end
        end
    end
end

-- Remove a picked category that holds no result. Returns true, or nil and a reason (see DeselectBlock).
function Run.Deselect(run, ctx, id)
    local why = Run.DeselectBlock(run, id)
    if why then return nil, why end
    local mine = {}
    for sid, cat in pairs(run.cat) do
        local rec = run.steps[sid]
        if cat == id and rec and not OUT[rec.verdict] then mine[#mine + 1] = rec end
    end
    local viewing = run.order[run.current]
    local after
    if viewing and run.cat[viewing] == id then
        for i = run.current + 1, #run.order do
            if run.cat[run.order[i]] ~= id then after = run.order[i]; break end
        end
    end
    for _, rec in ipairs(mine) do rec.attempts, rec.verdict, rec.evidence, rec.reopened = {}, "deselected", nil, nil end
    run.selected[id] = nil
    reorder(run, ctx)
    if viewing and run.cat[viewing] == id then
        run.current = Run.NextPending(run, after and Run.IndexOf(run, after) - 1 or 0) or (#run.order + 1) -- never a finished step
    end
    Run.Touch(run, ctx.now)
    return true
end

local function isOpenId(run, sid)
    local v = run.steps[sid] and run.steps[sid].verdict
    return v == "pending" or v == "unverified"
end

-- Open a category (its first open step) or a step by id. A category that was not picked is picked first.
-- Returns the kind ("category" or "step") and the step id now shown, or nil and a reason:
-- "unknown", "done" (no open step), "not for this client", "run ended".
function Run.Trigger(run, ctx, name)
    if run.endedAt then return nil, "run ended" end
    name = tostring(name or ""):lower()
    local cat = categoryOf(run, name)
    if cat and run.steps[name] then return nil, "ambiguous" end
    if cat then
        Run.Select(run, ctx, name)
        for _, sid in ipairs(run.order) do
            if run.cat[sid] == name and isOpenId(run, sid) then
                run.current = Run.IndexOf(run, sid)
                Run.Touch(run, ctx.now)
                return "category", sid
            end
        end
        return nil, "done"
    end
    local rec = run.steps[name]
    if not rec then return nil, "unknown" end
    if rec.verdict == "inapplicable" then return nil, "not for this client" end
    if rec.verdict == "deselected" then Run.Select(run, ctx, run.cat[name]) end
    run.current = Run.IndexOf(run, name)
    Run.Touch(run, ctx.now)
    return "step", name
end

-- Show one step on the card: only a step that is in the run (not unpicked, not for this client). It picks no category and
-- changes no result. An ended run still shows it, and its revision stays.
function Run.Show(run, ctx, id)
    local rec = run.steps[id]
    if not rec then return nil, "unknown" end
    local i = Run.IndexOf(run, id)
    if not i or rec.verdict == "inapplicable" or rec.verdict == "deselected" then return nil, "not offered" end
    run.current = i
    if not run.endedAt then Run.Touch(run, ctx.now) end
    return true
end

-- "failed" is no category id (Plan rejects it): it names every picked step whose result is fail or unverified.
Run.FAILED = "failed"

-- Reopen the picked steps of a category, or every failed or unverified step, as pending. Attempts stay.
-- Returns how many steps reopened, or nil and a reason.
function Run.Rerun(run, ctx, id)
    if run.endedAt then return nil, "run ended" end
    id = tostring(id or ""):lower()
    local failed = id == Run.FAILED and not categoryOf(run, id) -- a run saved before the name was reserved may hold a category called failed
    if not failed then
        if not categoryOf(run, id) then return nil, "unknown" end
        if not run.selected[id] then return nil, "not picked" end
    end
    local n, first, gone = 0, nil, {}
    for _, sid in ipairs(run.order) do
        local rec = run.steps[sid]
        if failed and (rec.verdict == "fail" or rec.verdict == "unverified") or not failed and run.cat[sid] == id then
            gone[sid] = true
            first = first or sid
            if rec.verdict ~= "pending" then
                rec.verdict, rec.evidence = "pending", nil
                rec.reopened = true -- only a step that had a result: an untouched step is not "awaiting retry"
                n = n + 1
            end
            -- A retry the card opened earlier holds old log positions and a start time: a fresh attempt starts instead.
            local last = rec.attempts[#rec.attempts]
            if last and not last.verdict then table.remove(rec.attempts) end
        end
    end
    local keep = {}
    for _, sid in ipairs(run.history or {}) do if not gone[sid] then keep[#keep + 1] = sid end end
    run.history = keep
    if first then run.current = Run.IndexOf(run, first) end
    Run.Touch(run, ctx.now)
    return n
end

function Run.Touch(run, now) run.revision = run.revision + 1; run.updated = now; stamp(run) end

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
            local a = { kind = "state", probe = def.probe, name = def.name, path = def.path, op = op, value = value, tolerance = def.tolerance }
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
    local a = { n = #rec.attempts + 1, started = ctx.now, snapshots = ns.Evidence.Snapshot(ctx.plan, ctx.env, stepOf(ctx, id)), build = ctx.build }
    -- After the runner settled the last attempt as unverified, the retry waits for the player: no loop of automatic results.
    -- (Undo resets the step to pending: that is the player acting, so the retry may settle itself.)
    if last and last.by == "auto" and last.verdict == "unverified" and rec.verdict == "unverified" then a.noauto = true end
    rec.attempts[#rec.attempts + 1] = a
    run.current = Run.IndexOf(run, id)
    Run.Touch(run, ctx.now)
    return a
end

Run.EXCERPT_BUDGET = 60000 -- bytes of kept log lines in one run; the export has a 2 MB limit

-- Bytes of the evidence text an attempt keeps: its excerpt lines, and the line and value text of its check hits.
local function excerptBytes(at)
    local n = 0
    for _, lines in pairs(at.excerpt or {}) do for _, l in ipairs(lines) do n = n + #l end end
    for _, o in ipairs(at.outcomes or {}) do
        n = n + #(o.observed or "")
        for _, h in ipairs(o.hits or {}) do n = n + #(h.line or "") + #(h.value or "") end
    end
    return n
end

-- Keeps the newest evidence text of a run inside the budget: the oldest attempts lose their excerpt and check hits first
-- (a check keeps its rule, counts and reason, and is marked trimmed).
function Run.TrimExcerpts(run)
    local all, total = {}, 0
    for _, rec in pairs(run.steps) do
        for _, at in ipairs(rec.attempts or {}) do
            local b = excerptBytes(at)
            if b > 0 then all[#all + 1], total = { at = at, b = b }, total + b end
        end
    end
    table.sort(all, function(x, y) return (x.at.finished or 0) < (y.at.finished or 0) end)
    for _, e in ipairs(all) do
        if total <= Run.EXCERPT_BUDGET then break end
        e.at.excerpt, total = nil, total - e.b
        for _, o in ipairs(e.at.outcomes or {}) do
            if o.hits or o.observed then o.trimmed = true end -- a reader can tell dropped text from none
            o.hits, o.observed = nil, nil
        end
    end
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
    if run.endedAt then return nil end
    local step, rec = stepOf(ctx, id), run.steps[id]
    if not (step and step.auto and rec) then return nil end
    local a = rec.attempts[#rec.attempts]
    if not a or a.verdict or a.noauto then return nil end
    local allMet, hasTimed, broke = true, false, false
    local items = ns.Evidence.Preview(step, a.snapshots, ctx.plan, ctx.env)
    for _, it in ipairs(items) do
        if it.timed then
            hasTimed = true
            if it.state == "bad" then broke = true end -- it can no longer hold: no reason to wait
        elseif it.state ~= "met" then allMet = false end
    end
    local due = step.timeout and (ctx.now - a.started) >= step.timeout
    if due or broke then return Run.Verdict(run, ctx, id, "pass", note, "auto") end
    if hasTimed then return nil end -- a check that something did not happen waits for the timeout
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
    if run.endedAt then return nil, "run ended" end
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
            local r, why, detail = ns.Evidence.Check(as, a.snapshots, ctx.plan, ctx.env, true)
            local o = { result = r, why = why, diagnostic = as.diagnostic or nil }
            -- A check that did not pass keeps what it looked at (also in a passing attempt: a diagnostic never gates it).
            if r ~= "pass" and detail then for k, v in pairs(detail) do o[k] = v end end
            a.outcomes[i] = o
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
    a.formatRev = Run.FORMAT_REV -- the format this attempt was written in (a run can hold attempts of several versions)
    -- A failed or unverified attempt keeps the log lines that arrived while it was open, so a reviewer need not find
    -- them in a log that may have rolled since.
    if effective == "fail" or effective == "unverified" then
        local ok, ex = pcall(ns.Evidence.Excerpt, step, a.snapshots, ctx.plan, ctx.env)
        a.excerpt = ok and ex or nil
    end
    Run.TrimExcerpts(run) -- also for a passing attempt: a failing diagnostic keeps check hits
    a.snapshots = nil
    verdict = effective
    rec.verdict = verdict
    rec.evidence = a.evidence
    rec.reopened = nil -- the retry has a result
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
    if run.endedAt then return false end
    local rec = run.steps[id]
    local a = rec and rec.attempts[#rec.attempts]
    if not a or not a.verdict then return false end
    table.remove(rec.attempts)
    rec.reopened = true -- the report cannot tell this from an untouched step when the only attempt is gone
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
    if run.endedAt then return false end
    local h = run.history or {}
    local id = table.remove(h)
    if not id then return false end
    local rec = run.steps[id]
    local last = rec.attempts[#rec.attempts]
    if last and not last.verdict then table.remove(rec.attempts) end
    return Run.Undo(run, ctx, id), id
end

function Run.Counts(run)
    local c = { pass = 0, partial = 0, fail = 0, skip = 0, unverified = 0, pending = 0, inapplicable = 0, deselected = 0 }
    for _, rec in pairs(run.steps) do c[rec.verdict] = (c[rec.verdict] or 0) + 1 end
    c.open = c.pending + c.unverified
    return c
end

-- An ended run has no current step: the card shows its results and nothing can resume.
function Run.CurrentId(run)
    if run.endedAt then return nil end
    return run.order[run.current]
end

-- Take a run that left the card back: an attempt left open belongs to the time it was open, so drop it.
-- The step opens a new one with a new log position and start time.
function Run.Resume(run, now)
    for _, rec in pairs(run.steps) do
        local a = rec.attempts[#rec.attempts]
        if a and not a.verdict then table.remove(rec.attempts) end
    end
    Run.Touch(run, now)
end

-- End a run for good. Every verdict, attempt and note stays; open attempts drop their bulky log snapshots.
-- Returns false when the run had already ended.
function Run.End(run, now)
    if run.endedAt then return false end
    for _, rec in pairs(run.steps) do
        local a = rec.attempts[#rec.attempts]
        if a and not a.verdict then a.snapshots = nil end
    end
    run.endedAt = now
    Run.Touch(run, now)
    return true
end
