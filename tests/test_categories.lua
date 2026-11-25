local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local R = ns.Run

-- Three categories: bank (3 steps), mail (2 steps, one for Forever only), ah (1 step).
local function step(id, extra)
    local s = { id = id, title = id, action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end
local function plan(declared)
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "t",
        sections = {
            { id = "bank", title = "Bank", steps = { step("b1"), step("b2"), step("b3") } },
            { id = "mail", title = "Mail", steps = { step("m1"), step("m2", { clients = { "forever-camelot" } }) } },
            { id = "ah", title = "Auction", steps = { step("a1") } },
        } }
    if declared then
        p.categories = { { id = "smoke", title = "Smoke" }, { id = "deep", title = "Deep" } }
        p.sections[1].category = "smoke"; p.sections[2].category = "deep"; p.sections[3].steps[1].category = "smoke"
    end
    return p
end
local function ctxOf(p, extra)
    local c = { plan = p, client = "classic-era", build = "1", character = "X", now = 100, env = {}, planDigest = "d" }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local function newRun(picks, declared)
    local ctx = ctxOf(plan(declared), { selected = picks })
    return R.New(ctx), ctx
end
local function pass(run, ctx, id) R.Begin(run, ctx, id); return R.Verdict(run, ctx, id, "pass") end

test("without declared categories each section is a category, all picked", function()
    local run = newRun()
    T.eq(#run.categories, 3); T.eq(run.categories[1].id, "bank")
    for _, id in ipairs({ "bank", "mail", "ah" }) do T.eq(run.selected[id], true) end
    T.eq(run.cat.b2, "bank"); T.eq(run.cat.m2, "mail", "an inapplicable step still has its category")
    T.eq(#run.order, 5)
end)

test("declared categories group steps across sections", function()
    local run = newRun(nil, true)
    T.eq(#run.categories, 2); T.eq(run.cat.a1, "smoke"); T.eq(run.cat.m1, "deep")
end)

test("unpicked categories are deselected and out of the order", function()
    local run = newRun({ "bank", "ah" })
    T.eq(run.steps.m1.verdict, "deselected"); T.eq(run.steps.b1.verdict, "pending")
    T.eq(#run.order, 4); T.eq(R.IndexOf(run, "m1"), nil)
    local c = R.Counts(run)
    T.eq(c.deselected, 1, "m2 is not for this client; m1 is not picked"); T.eq(c.inapplicable, 1); T.eq(c.open, 4)
end)

test("a run needs at least one picked category with steps", function()
    local ctx = ctxOf(plan(), { selected = {} })
    local run, why = R.New(ctx)
    T.eq(run, nil); T.eq(why, "no steps")
    ctx.client = "classic-era"; ctx.plan.sections[1].steps = { step("only", { clients = { "forever-camelot" } }) }
    ctx.selected = { "bank" }
    T.eq((R.New(ctx)), nil, "a picked category whose steps are all for another client has nothing to run")
end)

test("the run finishes when only the picked categories have results", function()
    local run, ctx = newRun({ "ah" })
    pass(run, ctx, "a1")
    T.eq(R.NextPending(run, 0), nil); T.eq(R.CurrentId(run), nil, "past the last step: the results screen")
    local state = R.OverallState(run)
    T.eq(state, "green")
end)

test("category state: blue, red, green", function()
    local run, ctx = newRun()
    T.eq((R.CategoryState(run, "bank")), "blue", "untested")
    pass(run, ctx, "b1")
    T.eq((R.CategoryState(run, "bank")), "blue", "some results, steps still untested")
    pass(run, ctx, "b2"); pass(run, ctx, "b3")
    T.eq((R.CategoryState(run, "bank")), "green")
    R.Begin(run, ctx, "m1"); R.Verdict(run, ctx, "m1", "fail", "bad")
    local state, c = R.CategoryState(run, "mail")
    T.eq(state, "red"); T.eq(c.fail, 1); T.eq(c.total, 1, "m2 is not for this client and does not count")
    T.eq((R.CategoryState(run, "ah")), "blue")
end)

test("partial and unverified read yellow even when nothing else is open", function()
    local run, ctx = newRun({ "ah" })
    R.Begin(run, ctx, "a1"); R.Verdict(run, ctx, "a1", "partial")
    T.eq((R.CategoryState(run, "ah")), "yellow")
    local run2, ctx2 = newRun({ "ah" })
    ctx2.plan.sections[3].steps[1].verify = { "player", "assertions" }
    ctx2.plan.sections[3].steps[1].assertions = { { kind = "state", probe = "global-value", name = "Zed", op = "eq", value = 1 } }
    R.Begin(run2, ctx2, "a1"); R.Verdict(run2, ctx2, "a1", "pass")
    T.eq(run2.steps.a1.verdict, "unverified")
    T.eq((R.CategoryState(run2, "ah")), "yellow")
end)

test("a failed step that is redone and passes turns the category green", function()
    local run, ctx = newRun({ "ah" })
    R.Begin(run, ctx, "a1"); R.Verdict(run, ctx, "a1", "fail")
    T.eq((R.CategoryState(run, "ah")), "red")
    R.Undo(run, ctx, "a1"); pass(run, ctx, "a1")
    T.eq((R.CategoryState(run, "ah")), "green")
end)

test("only skips read grey, not green", function()
    local run, ctx = newRun({ "ah" })
    R.Begin(run, ctx, "a1"); R.Verdict(run, ctx, "a1", "skip")
    T.eq((R.CategoryState(run, "ah")), "grey")
    T.eq((R.OverallState(run)), "grey")
end)

test("an unpicked category reads off and the overall state ignores it", function()
    local run, ctx = newRun({ "ah" })
    local state, c = R.CategoryState(run, "bank")
    T.eq(state, "off"); T.eq(c.total, 0, "deselected steps are not counted")
    pass(run, ctx, "a1")
    T.eq((R.OverallState(run)), "green")
end)

test("overall is red when any category failed", function()
    local run, ctx = newRun()
    pass(run, ctx, "b1")
    R.Begin(run, ctx, "a1"); R.Verdict(run, ctx, "a1", "fail")
    T.eq((R.OverallState(run)), "red")
end)

test("adding a category mid-run keeps results and plan order", function()
    local run, ctx = newRun({ "bank", "ah" })
    pass(run, ctx, "b1")
    local viewing = R.CurrentId(run)
    T.eq(R.Select(run, ctx, "mail"), true)
    T.eq(table.concat(run.order, ","), "b1,b2,b3,m1,a1")
    T.eq(run.steps.b1.verdict, "pass"); T.eq(run.steps.m1.verdict, "pending")
    T.eq(R.CurrentId(run), viewing)
    T.eq(R.Select(run, ctx, "mail"), false, "already picked")
    local _, why = R.Select(run, ctx, "nope"); T.eq(why, "unknown category")
    -- Undo still works across the reorder
    T.eq(R.UndoLast(run, ctx) and run.steps.b1.verdict, "pending")
end)

test("a clean category leaves the run; the others and the order stay", function()
    local run, ctx = newRun()
    R.Begin(run, ctx, "m1") -- an open attempt only
    T.eq(R.Deselect(run, ctx, "mail"), true)
    T.eq(run.selected.mail, nil); T.eq(run.steps.m1.verdict, "deselected"); T.eq(#run.steps.m1.attempts, 0)
    T.eq(#run.order, 4); T.eq(R.IndexOf(run, "m1"), nil)
    T.eq(R.Select(run, ctx, "mail"), true, "it can come back"); T.eq(run.steps.m1.verdict, "pending")
end)

test("a reopened step that leaves the run loses its marker", function()
    local run, ctx = newRun()
    pass(run, ctx, "m1"); R.Undo(run, ctx, "m1")
    T.eq(run.steps.m1.reopened, true)
    T.eq(R.Deselect(run, ctx, "mail"), true)
    T.eq(run.steps.m1.reopened, nil)
    T.eq(R.Select(run, ctx, "mail"), true); T.eq(run.steps.m1.verdict, "pending"); T.eq(run.steps.m1.reopened, nil)
end)

test("a category with a result or a finished attempt is not removed", function()
    local run, ctx = newRun()
    pass(run, ctx, "m1")
    local ok, why = R.Deselect(run, ctx, "mail"); T.eq(ok, nil); T.eq(why, "has results")
    T.eq(run.selected.mail, true)
    R.Rerun(run, ctx, "mail") -- pending again, the attempt stays
    ok, why = R.Deselect(run, ctx, "mail"); T.eq(why, "has results")
end)

test("the last picked category, an unpicked one and an unknown one are refused", function()
    local run, ctx = newRun({ "bank" })
    local _, why = R.Deselect(run, ctx, "bank"); T.eq(why, "last category")
    _, why = R.Deselect(run, ctx, "mail"); T.eq(why, "not picked")
    _, why = R.Deselect(run, ctx, "zzz"); T.eq(why, "unknown category")
    run.endedAt = 1; _, why = R.Deselect(run, ctx, "bank"); T.eq(why, "run ended")
end)

test("removing the viewed category moves to the next open step of another category", function()
    local run, ctx = newRun()
    run.current = R.IndexOf(run, "b2")
    T.eq(R.Deselect(run, ctx, "bank"), true)
    T.eq(R.CurrentId(run), "m1")
    local run2, ctx2 = newRun()
    run2.current = R.IndexOf(run2, "m1")
    R.Deselect(run2, ctx2, "bank")
    T.eq(R.CurrentId(run2), "m1", "a step in another category stays shown")
end)

test("removing the viewed category never lands on a finished step", function()
    local run, ctx = newRun()
    pass(run, ctx, "m1"); pass(run, ctx, "a1") -- finished steps after bank
    run.current = R.IndexOf(run, "b1")
    T.eq(R.Deselect(run, ctx, "bank"), true)
    T.eq(run.steps[R.CurrentId(run) or "x"] and run.steps[R.CurrentId(run)].verdict, nil, "nothing open: the results screen")
    local run2, ctx2 = newRun()
    pass(run2, ctx2, "m1")
    run2.current = R.IndexOf(run2, "b1")
    R.Deselect(run2, ctx2, "bank")
    T.eq(R.CurrentId(run2), "a1", "the next open step, skipping the finished one")
end)

test("the last category with an applicable step cannot leave, even when another category is picked", function()
    local ctx = ctxOf(plan(), { selected = { "bank", "mail" } })
    ctx.plan.sections[1].steps = { step("b1", { clients = { "forever-camelot" } }) }
    local run = R.New(ctx)
    local ok, why = R.Deselect(run, ctx, "mail"); T.eq(ok, nil); T.eq(why, "last category", "bank holds no step for this client")
    T.ok(#run.order > 0)
end)

test("ids that differ only in case are removed exactly", function()
    local p = plan(); p.sections[2].id = "Bank"; p.sections[2].title = "Upper"
    local ctx = ctxOf(p)
    local run = R.New(ctx)
    T.eq(R.Deselect(run, ctx, "Bank"), true)
    T.eq(run.selected.Bank, nil); T.eq(run.selected.bank, true)
end)

test("adding a category to a finished run opens its first step", function()
    local run, ctx = newRun({ "ah" })
    pass(run, ctx, "a1")
    T.eq(run.current, 2)
    R.Select(run, ctx, "bank")
    T.eq(R.CurrentId(run), "b1")
end)

test("trigger a category shows its first open step and picks it when needed", function()
    local run, ctx = newRun({ "ah" })
    local kind, id = R.Trigger(run, ctx, "bank")
    T.eq(kind, "category"); T.eq(id, "b1"); T.eq(run.selected.bank, true); T.eq(R.CurrentId(run), "b1")
    pass(run, ctx, "b1")
    kind, id = R.Trigger(run, ctx, "BANK")
    T.eq(id, "b2", "case does not matter and finished steps are skipped")
end)

test("trigger a category with no open step says so and changes nothing", function()
    local run, ctx = newRun({ "ah" })
    pass(run, ctx, "a1")
    local before = run.current
    local kind, why = R.Trigger(run, ctx, "ah")
    T.eq(kind, nil); T.eq(why, "done"); T.eq(run.current, before)
end)

test("a name that matches a category and a step is refused", function()
    local run, ctx = newRun({ "ah" })
    run.steps.bank = { attempts = {}, verdict = "pending" }
    local before = run.current
    local kind, why = R.Trigger(run, ctx, "bank")
    T.eq(kind, nil); T.eq(why, "ambiguous"); T.eq(run.current, before); T.eq(run.selected.bank, nil, "the category was not added")
end)

test("trigger a step by id, including a deselected one and one for another client", function()
    local run, ctx = newRun({ "ah" })
    local kind, id = R.Trigger(run, ctx, "m1")
    T.eq(kind, "step"); T.eq(id, "m1"); T.eq(run.selected.mail, true); T.eq(R.CurrentId(run), "m1")
    local k, why = R.Trigger(run, ctx, "m2"); T.eq(k, nil); T.eq(why, "not for this client")
    k, why = R.Trigger(run, ctx, "nothing"); T.eq(k, nil); T.eq(why, "unknown")
    local before = run.current
    R.Trigger(run, ctx, "nothing"); T.eq(run.current, before)
end)

test("trigger sends no input: it only moves the viewed step", function()
    local run, ctx = newRun()
    local before = run.steps.b1.verdict
    R.Trigger(run, ctx, "mail")
    T.eq(run.steps.m1.verdict, "pending"); T.eq(run.steps.b1.verdict, before)
    T.eq(#run.steps.m1.attempts, 0, "no attempt is opened by the trigger itself")
end)

test("rerun reopens the steps of a category and keeps their attempts", function()
    local run, ctx = newRun()
    pass(run, ctx, "b1"); pass(run, ctx, "b2"); pass(run, ctx, "b3")
    T.eq((R.CategoryState(run, "bank")), "green")
    local n = R.Rerun(run, ctx, "bank")
    T.eq(n, 3); T.eq((R.CategoryState(run, "bank")), "blue")
    T.eq(#run.steps.b1.attempts, 1, "the earlier attempt stays"); T.eq(R.CurrentId(run), "b1")
    for _, id in ipairs(run.history) do T.ok(run.cat[id] ~= "bank", "history no longer holds reopened steps") end
    pass(run, ctx, "b1")
    T.eq(#run.steps.b1.attempts, 2); T.eq((R.CategoryState(run, "bank")), "blue")
end)

test("rerun failed reopens every failed or unverified step in every picked category and keeps the passes", function()
    local run, ctx = newRun({ "bank", "mail" })
    pass(run, ctx, "b1")
    R.Begin(run, ctx, "b2"); R.Verdict(run, ctx, "b2", "fail")
    R.Begin(run, ctx, "m1"); R.Verdict(run, ctx, "m1", "pass"); run.steps.m1.verdict = "unverified" -- as an assertion with no evidence leaves it
    local n = R.Rerun(run, ctx, "FAILED")
    T.eq(n, 2); T.eq(run.steps.b1.verdict, "pass", "a pass stays")
    T.eq(run.steps.b2.verdict, "pending"); T.eq(run.steps.m1.verdict, "pending")
    T.eq(run.steps.a1.verdict, "deselected", "an unpicked category stays out")
    T.eq(#run.steps.b2.attempts, 1, "the failed attempt stays"); T.eq(R.CurrentId(run), "b2")
    for _, id in ipairs(run.history) do T.ok(id ~= "b2" and id ~= "m1", "undo no longer reaches reopened steps") end
    T.eq(R.Rerun(run, ctx, "failed"), 0, "nothing left to reopen")
end)

test("a run saved with a category called failed keeps it: its rerun is that category's", function()
    local run, ctx = newRun()
    run.categories[#run.categories + 1] = { id = "failed", title = "Old" }; run.cat.a1 = "failed"; run.selected.failed = true
    pass(run, ctx, "a1"); R.Begin(run, ctx, "b1"); R.Verdict(run, ctx, "b1", "fail")
    T.eq(R.Rerun(run, ctx, "failed"), 1); T.eq(run.steps.a1.verdict, "pending"); T.eq(run.steps.b1.verdict, "fail", "no global retry")
end)

test("rerun refuses an unknown or unpicked category and an ended run", function()
    local run, ctx = newRun({ "ah" })
    local n, why = R.Rerun(run, ctx, "bank"); T.eq(n, nil); T.eq(why, "not picked")
    n, why = R.Rerun(run, ctx, "zzz"); T.eq(n, nil); T.eq(why, "unknown")
    run.endedAt = 5
    n, why = R.Rerun(run, ctx, "ah"); T.eq(why, "run ended")
    n, why = R.Trigger(run, ctx, "ah"); T.eq(why, "run ended")
    n, why = R.Select(run, ctx, "bank"); T.eq(why, "run ended")
end)

test("a run saved before categories reads as every section picked", function()
    local run, ctx = newRun()
    run.categories, run.cat, run.selected = nil, nil, nil
    R.Normalize(run, ctx.plan, ctx.client)
    T.eq(#run.categories, 3); T.eq(run.selected.mail, true); T.eq(run.cat.b1, "bank"); T.eq(run.cat.m2, "mail")
    T.eq((R.CategoryState(run, "bank")), "blue")
    local again = run.categories
    R.Normalize(run, ctx.plan, ctx.client); T.eq(run.categories, again, "a second call changes nothing")
end)

test("the export keeps the categories and the picked set", function()
    local run = newRun({ "bank" })
    local out = R.Export(run)
    T.eq(out.selected.bank, true); T.eq(out.selected.mail, nil); T.eq(out.cat.m1, "mail")
    T.eq(out.steps.m1.verdict, "deselected")
end)

test("the state rule agrees with the shared fixture", function()
    local f = assert(io.open("tests/fixtures/category-rule.json")); local text = f:read("*a"); f:close()
    local cases = ns.Json.Decode(text)
    T.ok(#cases > 10, "fixture is read")
    for i, case in ipairs(cases) do
        local c = { pass = 0, partial = 0, fail = 0, skip = 0, unverified = 0, pending = 0 }
        for k, v in pairs(case.counts) do c[k] = v end
        c.resolved = c.pass + c.partial + c.fail + c.skip; c.open = c.pending + c.unverified
        T.eq(R.Rule(c), case.state, "case " .. i)
    end
end)

test("rerun drops a retry the card had opened, so old log positions cannot satisfy it", function()
    local run, ctx = newRun({ "bank" })
    R.Begin(run, ctx, "b1")
    local stale = run.steps.b1.attempts[1]
    stale.started = 5
    R.Rerun(run, ctx, "bank")
    T.eq(#run.steps.b1.attempts, 0, "the open attempt is gone")
    local fresh = R.Begin(run, ctx, "b1")
    T.ok(fresh ~= stale and fresh.started == ctx.now, "a new attempt starts from now")
end)
test("normalizing an old run raises its revision once, so a collected copy is not the same revision", function()
    local run, ctx = newRun()
    run.categories, run.cat, run.selected = nil, nil, nil
    local rev = run.revision
    R.Normalize(run, ctx.plan, ctx.client)
    T.eq(run.revision, rev + 1)
    R.Normalize(run, ctx.plan, ctx.client)
    T.eq(run.revision, rev + 1, "once")
end)
test("a requirement with approx reads its tolerance", function()
    local run, ctx = newRun()
    ctx.plan.requirements = { r = { text = "r", probe = "global-value", name = "G", path = "x", op = "approx", value = 1, tolerance = 0.5 } }
    ctx.env.G = { x = 1.2 }
    T.eq(#R.Blocked(ctx, { requires = { "r" } }), 0)
    ctx.env.G = { x = 2 }
    T.eq(#R.Blocked(ctx, { requires = { "r" } }), 1)
end)

finish()
