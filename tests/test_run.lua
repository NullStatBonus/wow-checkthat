local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local R = ns.Run
local function mk()
    local plan = { kind = "plan", wtt = 1, addon = "KeepThat", title = "t",
        logs = { debug = { global = "DB", path = "log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "a", title = "A", action = { kind = "manual", text = "t" }, expect = "e",
              verify = { "player", "assertions" }, assertions = { { kind = "log", source = "debug", contains = "ok" } } },
            { id = "b", title = "B", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } },
            { id = "c", title = "C", clients = { "forever-camelot" }, action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } },
        } } } }
    local env = { DB = { log = { "old" } } }
    local ctx = { plan = plan, client = "classic-era", build = "1.15", character = "X", now = 100, env = env, planDigest = "d" }
    return R.New(ctx), ctx, env
end
test("run marks other-client steps inapplicable", function()
    local run = mk()
    T.eq(run.steps.c.verdict, "inapplicable"); T.eq(#run.order, 2)
end)
test("pass with matching evidence advances", function()
    local run, ctx, env = mk()
    R.Begin(run, ctx, "a")
    env.DB.log[#env.DB.log + 1] = "ok line"
    local a = R.Verdict(run, ctx, "a", "pass")
    T.eq(a.verdict, "pass"); T.eq(a.evidence, "matched"); T.eq(R.CurrentId(run), "b")
end)
test("player pass with missing evidence is unverified, not pass", function()
    local run, ctx = mk()
    R.Begin(run, ctx, "a")
    local a = R.Verdict(run, ctx, "a", "pass")
    T.eq(a.verdict, "unverified"); T.eq(a.claimed, "pass"); T.eq(R.CurrentId(run), "a")
end)
test("contradicting evidence fails", function()
    local run, ctx, env = mk()
    ctx.plan.sections[1].steps[1].assertions[1].absent = true
    R.Begin(run, ctx, "a")
    env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.Verdict(run, ctx, "a", "pass").verdict, "fail")
end)
test("diagnostic assertions never gate", function()
    local run, ctx = mk()
    ctx.plan.sections[1].steps[1].assertions[1].diagnostic = true
    R.Begin(run, ctx, "a")
    local a = R.Verdict(run, ctx, "a", "pass")
    T.eq(a.verdict, "pass"); T.eq(a.outcomes[1].result, "unverified")
    T.eq(a.evidence, "diagnostic-only", "never reports matched when nothing required ran")
end)
test("partial is gated by evidence like pass and moves on", function()
    local run, ctx, env = mk()
    R.Begin(run, ctx, "a")
    local a = R.Verdict(run, ctx, "a", "partial", "works but slow")
    T.eq(a.verdict, "unverified"); T.eq(a.claimed, "partial")
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok line"
    local b = R.Verdict(run, ctx, "a", "partial", "works but slow")
    T.eq(b.verdict, "partial"); T.eq(b.evidence, "matched"); T.eq(b.note, "works but slow")
    T.eq(R.CurrentId(run), "b", "moves on like a pass")
    T.eq(R.Counts(run).partial, 1)
end)
test("fail moves on; only missing evidence keeps the step open", function()
    local run, ctx = mk()
    R.Begin(run, ctx, "b")
    R.Verdict(run, ctx, "b", "fail", "broken")
    T.eq(run.steps.b.verdict, "fail")
    T.ok(R.CurrentId(run) ~= "b", "moved on after Fail")
end)
test("navigation: back and forth, results screen only when nothing is pending, advance finds earlier pending steps", function()
    local run, ctx = mk()                     -- steps a, b (c is for the other client)
    T.eq(R.CurrentId(run), "a")
    T.eq(R.Goto(run, 1), 2); T.eq(R.CurrentId(run), "b")
    T.eq(R.Goto(run, 1), 2, "cannot pass the last step while a step is pending")
    T.eq(R.Goto(run, -5), 1, "clamped at the first step")
    -- finish b out of order, then a: advance returns to the pending one, then completes
    R.Goto(run, 1); R.Begin(run, ctx, "b"); R.Verdict(run, ctx, "b", "pass")
    T.eq(R.CurrentId(run), "a", "the earlier pending step is next")
    R.Begin(run, ctx, "a"); R.Verdict(run, ctx, "a", "skip")
    T.eq(run.current, #run.order + 1, "run complete")
    T.eq(R.Goto(run, -1), 2, "can go back from the results screen")
    T.eq(R.Goto(run, 1), 3, "and forward to it again")
end)
test("preview of the current attempt follows the log", function()
    local run, ctx, env = mk()
    R.Begin(run, ctx, "a")
    T.eq(R.Preview(run, ctx, "a")[1].state, "waiting")
    env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.Preview(run, ctx, "a")[1].state, "met")
end)
test("retry opens a fresh attempt and keeps history; undo reopens", function()
    local run, ctx = mk()
    R.Begin(run, ctx, "a"); R.Verdict(run, ctx, "a", "fail", "bad")
    R.Begin(run, ctx, "a")
    T.eq(#run.steps.a.attempts, 2)
    R.Verdict(run, ctx, "a", "skip")
    T.eq(R.Undo(run, ctx, "a"), true)
    T.eq(#run.steps.a.attempts, 1); T.eq(run.steps.a.verdict, "pending")
end)
test("reload keeps an open attempt", function()
    local run, ctx = mk()
    local a1 = R.Begin(run, ctx, "a")
    T.eq(R.Begin(run, ctx, "a"), a1)
end)
test("revision bumps on every change and counts", function()
    local run, ctx = mk()
    local r0 = run.revision
    R.Begin(run, ctx, "b"); R.Verdict(run, ctx, "b", "pass")
    T.ok(run.revision > r0)
    local c = R.Counts(run)
    T.eq(c.pass, 1); T.eq(c.inapplicable, 1); T.eq(c.pending, 1)
end)
test("requirements block when probe fails", function()
    local run, ctx = mk()
    ctx.plan.requirements = { dbg = { text = "debug on", probe = "global-value", name = "DB", path = "debug", op = "eq", value = true } }
    local step = { requires = { "dbg" } }
    T.eq(#R.Blocked(ctx, step), 1)
    ctx.env.DB.debug = true
    T.eq(#R.Blocked(ctx, step), 0)
end)
finish()
