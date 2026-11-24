local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local R = ns.Run
local function mk()
    local plan = { kind = "plan", ct = 1, addon = "KeepThat", title = "t",
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
test("a failed attempt keeps the first new log lines of the source its step checks, cut", function()
    local run, ctx, env = mk()
    ctx.plan.sections[1].steps[1].assertions[1].absent = true
    R.Begin(run, ctx, "a")
    env.DB.log[#env.DB.log + 1] = "ok line " .. ("x"):rep(300)
    for i = 1, 30 do env.DB.log[#env.DB.log + 1] = "more " .. i end
    local a = R.Verdict(run, ctx, "a", "pass")
    T.eq(a.verdict, "fail")
    local ex = a.excerpt.debug
    T.eq(#ex, ns.Evidence.EXCERPT, "at most 20 lines"); T.eq(#ex[1], ns.Evidence.EXCERPT_LEN, "each line cut"); T.eq(ex[2], "more 1")
    T.eq(a.snapshots, nil, "the bulky positions still go")
    T.eq(R.Export(run).steps.a.attempts[1].excerpt.debug[2], "more 1", "the export carries it")
end)
test("an unverified attempt keeps the lines too, and a pass or a step with no log check keeps none", function()
    local run, ctx, env = mk()
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "unrelated"
    local a = R.Verdict(run, ctx, "a", "pass")
    T.eq(a.verdict, "unverified"); T.eq(a.excerpt.debug[1], "unrelated")
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok line"
    local b = R.Verdict(run, ctx, "a", "pass"); T.eq(b.verdict, "pass"); T.eq(b.excerpt, nil)
    R.Begin(run, ctx, "b"); local c = R.Verdict(run, ctx, "b", "fail", "broken"); T.eq(c.excerpt, nil, "nothing to read")
end)
test("an attempt with no saved position keeps no excerpt, so old lines are not shown as new", function()
    local run, ctx = mk()
    R.Begin(run, ctx, "a"); run.steps.a.attempts[1].snapshots = {}
    local a = R.Verdict(run, ctx, "a", "pass"); T.eq(a.verdict, "unverified"); T.eq(a.excerpt, nil)
end)
test("a log that rolled keeps no excerpt and an unreadable one never stops the result", function()
    local run, ctx, env = mk()
    R.Begin(run, ctx, "a")
    env.DB = nil
    local a = R.Verdict(run, ctx, "a", "pass"); T.eq(a.verdict, "unverified"); T.eq(a.excerpt, nil)
end)
test("a run keeps the newest excerpts inside the byte budget and drops the oldest first", function()
    local run, ctx, env = mk()
    ctx.plan.sections[1].steps[1].assertions[1].absent = true
    local old = R.EXCERPT_BUDGET; R.EXCERPT_BUDGET = 350
    for i = 1, 4 do
        ctx.now = 100 + i
        R.Begin(run, ctx, "a")
        env.DB.log[#env.DB.log + 1] = ("ok line %d "):format(i) .. ("x"):rep(150)
        R.Verdict(run, ctx, "a", "pass")
        run.steps.a.verdict = "pending"
    end
    R.EXCERPT_BUDGET = old
    local at = run.steps.a.attempts
    T.eq(at[1].excerpt, nil, "the oldest lost its lines"); T.eq(at[2].excerpt, nil)
    T.ok(at[3].excerpt and at[4].excerpt, "the newest kept them")
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

test("an unverified step stays open: finishing the others does not complete the run", function()
    local run, ctx = mk()
    R.Begin(run, ctx, "a"); R.Verdict(run, ctx, "a", "pass")        -- no evidence: unverified
    T.eq(run.steps.a.verdict, "unverified")
    R.Goto(run, 1); R.Begin(run, ctx, "b"); R.Verdict(run, ctx, "b", "pass")
    T.eq(R.CurrentId(run), "a", "the open step comes back")
    T.eq(R.Counts(run).open, 1)
end)
test("export keeps a step that is named snapshots", function()
    local run, ctx = mk()
    ctx.plan.sections[1].steps[2].id = "snapshots"
    run = R.New(ctx)
    R.Begin(run, ctx, "snapshots"); R.Verdict(run, ctx, "snapshots", "pass")
    local out = R.Export(run)
    T.ok(out.steps.snapshots and out.steps.snapshots.verdict == "pass", "step survives the export")
    T.ok(out.steps.a.attempts[1] == nil or out.steps.a.attempts[1].snapshots == nil)
end)
test("run ids differ per character", function()
    local _, ctx = mk()
    local r1 = R.New(ctx); ctx.character = "Other-Realm"; local r2 = R.New(ctx)
    T.ok(r1.runId ~= r2.runId, r1.runId .. " vs " .. r2.runId)
end)
test("addon-loaded requirement defaults to loaded, not merely answered", function()
    local run, ctx, env = mk()
    ctx.plan.requirements = { dfl = { text = "DFL", probe = "addon-loaded", name = "DFL" } }
    ctx.plan.sections[1].steps[2].requires = { "dfl" }
    env.IsAddOnLoaded = function() return false end
    T.eq(#R.Blocked(ctx, ctx.plan.sections[1].steps[2]), 1, "an unloaded addon blocks")
    env.IsAddOnLoaded = function() return true end
    T.eq(#R.Blocked(ctx, ctx.plan.sections[1].steps[2]), 0)
end)

-- Auto steps: the runner settles them from the evidence alone.
local function mkAuto(timeout)
    local run, ctx, env = mk()
    local st = ctx.plan.sections[1].steps[1]
    st.verify = { "assertions" }; st.auto = true; st.timeout = timeout
    return run, ctx, env, st
end
test("auto: a player pass is unchanged and carries no auto mark", function()
    local run, ctx, env = mk()
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.Verdict(run, ctx, "a", "pass").by, nil)
end)
test("auto: the step passes by itself when the line appears", function()
    local run, ctx, env = mkAuto()
    R.Begin(run, ctx, "a")
    T.eq(R.AutoSettle(run, ctx, "a"), nil); T.eq(run.steps.a.verdict, "pending")
    env.DB.log[#env.DB.log + 1] = "ok line"
    local a = R.AutoSettle(run, ctx, "a")
    T.eq(a.verdict, "pass"); T.eq(a.evidence, "matched"); T.eq(a.by, "auto"); T.eq(a.claimed, "pass")
    T.eq(R.CurrentId(run), "b", "moves on")
end)
test("auto: nothing is recorded while a required check is still waiting", function()
    local run, ctx, env, st = mkAuto()
    st.assertions[2] = { kind = "log", source = "debug", contains = "second" }
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.AutoSettle(run, ctx, "a"), nil)
    T.eq(run.steps.a.verdict, "pending"); T.eq(#run.steps.a.attempts, 1); T.eq(run.steps.a.attempts[1].verdict, nil)
end)
test("auto: a step that is not auto is never settled by the runner", function()
    local run, ctx, env = mk()
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.AutoSettle(run, ctx, "a"), nil); T.eq(run.steps.a.verdict, "pending")
end)
test("auto: the player's result comes first and is not overwritten", function()
    local run, ctx, env = mkAuto()
    R.Begin(run, ctx, "a"); R.Verdict(run, ctx, "a", "fail", "no")
    env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.AutoSettle(run, ctx, "a"), nil)
    T.eq(run.steps.a.verdict, "fail"); T.eq(#run.steps.a.attempts, 1)
end)
test("auto: undo reopens the step and the runner can settle it again", function()
    local run, ctx, env = mkAuto()
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok line"; R.AutoSettle(run, ctx, "a")
    T.eq(R.UndoLast(run, ctx), true); T.eq(run.steps.a.verdict, "pending")
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok again"
    T.eq(R.AutoSettle(run, ctx, "a").verdict, "pass")
end)
local function stateStep(st)
    st.assertions = { { kind = "state", probe = "global-value", name = "G", path = "v", op = "eq", value = 2 } }
end
test("auto: at the timeout contradicting evidence records fail", function()
    local run, ctx, env, st = mkAuto(30); stateStep(st); env.G = { v = 1 }
    R.Begin(run, ctx, "a")
    ctx.now = 129; T.eq(R.AutoSettle(run, ctx, "a"), nil, "not due yet")
    ctx.now = 130
    local a = R.AutoSettle(run, ctx, "a")
    T.eq(a.verdict, "fail"); T.eq(a.evidence, "contradicts"); T.eq(a.by, "auto")
end)
test("auto: at the timeout missing evidence records unverified and the step stays open", function()
    local run, ctx = mkAuto(30)
    R.Begin(run, ctx, "a"); ctx.now = 131
    local a = R.AutoSettle(run, ctx, "a")
    T.eq(a.verdict, "unverified"); T.eq(a.by, "auto"); T.eq(R.CurrentId(run), "a")
end)
test("auto: a check that reads bad and then recovers before the timeout passes", function()
    local run, ctx, env, st = mkAuto(30); stateStep(st); env.G = { v = 1 }
    R.Begin(run, ctx, "a")
    ctx.now = 110; T.eq(R.AutoSettle(run, ctx, "a"), nil, "bad is not a failure before the timeout")
    env.G.v = 2; ctx.now = 120
    T.eq(R.AutoSettle(run, ctx, "a").verdict, "pass")
end)
test("auto: the timeout counts from when the attempt opened, also after a reload", function()
    local run, ctx, env, st = mkAuto(30); stateStep(st); env.G = { v = 1 }
    R.Begin(run, ctx, "a")
    ctx.now = 110; R.AutoSettle(run, ctx, "a")
    local saved = ns.Json and ns.Json.Decode and ns.Json.Decode(ns.Json.Encode(run)) or run
    ctx.now = 130
    T.eq(R.AutoSettle(saved, ctx, "a").verdict, "fail", "30 s after the open, not after the reload")
end)
test("auto: an unverified timeout does not loop; Redo lets the runner settle again", function()
    local run, ctx, env = mkAuto(30)
    R.Begin(run, ctx, "a"); ctx.now = 131; R.AutoSettle(run, ctx, "a")
    local b = R.Begin(run, ctx, "a")             -- the card opens the retry straight away
    T.eq(#run.steps.a.attempts, 2)
    ctx.now = 500; env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.AutoSettle(run, ctx, "a"), nil, "no second automatic result until the player acts")
    T.eq(#run.steps.a.attempts, 2)
    R.Verdict(run, ctx, "a", "pass")             -- the player acts: unverified or pass, either closes it
    R.Begin(run, ctx, "a")                       -- the player acted, so a new attempt may settle itself
    env.DB.log[#env.DB.log + 1] = "ok again"
    T.eq(R.AutoSettle(run, ctx, "a").verdict, "pass")
end)
test("auto: settling reads only the evidence sources and sends no input", function()
    local run, ctx, env, st = mkAuto(30); stateStep(st); env.G = { v = 1 }
    local touched = {}
    ctx.env = setmetatable({}, { __index = function(_, k) touched[k] = true; return env[k] end })
    R.Begin(run, ctx, "a"); ctx.now = 200
    R.AutoSettle(run, ctx, "a")
    local extra = {}
    for k in pairs(touched) do if k ~= "DB" and k ~= "G" then extra[#extra + 1] = tostring(k) end end
    T.eq(#extra, 0, "touched: " .. table.concat(extra, ","))
end)

test("auto: a check that flips between the live read and the recording read does not fail the step early", function()
    local run, ctx, env, st = mkAuto(30); stateStep(st)
    local reads = 0
    setmetatable(env, { __index = function(_, k) if k == "G" then reads = reads + 1; return { v = reads == 1 and 2 or 1 } end end })
    R.Begin(run, ctx, "a")
    T.eq(R.AutoSettle(run, ctx, "a"), nil, "nothing is recorded when the recording read disagrees")
    T.eq(run.steps.a.verdict, "pending"); T.eq(run.steps.a.attempts[1].verdict, nil)
end)
test("auto: a step that asks for a reload waits for it, unless the timeout is due", function()
    local run, ctx, env, st = mkAuto(30); st.reload = "after_action"
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.AutoSettle(run, ctx, "a"), nil, "checks are met but the reload has not happened")
    run.steps.a.attempts[1].reloaded = true
    T.eq(R.AutoSettle(run, ctx, "a").verdict, "pass")
    local run2, ctx2, env2, st2 = mkAuto(30); st2.reload = "after_action"
    R.Begin(run2, ctx2, "a"); ctx2.now = 131
    T.eq(R.AutoSettle(run2, ctx2, "a").verdict, "unverified", "the timeout still settles")
end)
test("auto: Undo is the player acting, so the step can settle itself again", function()
    local run, ctx, env = mkAuto(30)
    R.Begin(run, ctx, "a"); ctx.now = 131; R.AutoSettle(run, ctx, "a")     -- unverified by the runner
    R.Begin(run, ctx, "a")                                                 -- retry, waits for the player
    R.Verdict(run, ctx, "a", "skip")
    T.eq(R.UndoLast(run, ctx), true); T.eq(run.steps.a.verdict, "pending")
    local a = R.Begin(run, ctx, "a")
    T.eq(a.noauto, nil, "the reopened attempt may settle")
    env.DB.log[#env.DB.log + 1] = "ok again"
    T.eq(R.AutoSettle(run, ctx, "a").verdict, "pass")
end)
test("auto: a note typed while waiting is kept", function()
    local run, ctx, env = mkAuto()
    R.Begin(run, ctx, "a"); env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.AutoSettle(run, ctx, "a", "my note").note, "my note")
end)
test("auto: seconds left count from when the attempt opened", function()
    local run, ctx = mkAuto(30)
    R.Begin(run, ctx, "a")
    T.eq(R.TimeLeft(run, ctx, "a"), 30)
    ctx.now = 112; T.eq(R.TimeLeft(run, ctx, "a"), 18)
    ctx.now = 400; T.eq(R.TimeLeft(run, ctx, "a"), 0, "never negative")
end)
test("auto: no countdown without a timeout, without auto, or once the runner has handed over", function()
    local run, ctx = mkAuto(nil); R.Begin(run, ctx, "a")
    T.eq(R.TimeLeft(run, ctx, "a"), nil, "no timeout")
    local run2, ctx2 = mk(); R.Begin(run2, ctx2, "a")
    T.eq(R.TimeLeft(run2, ctx2, "a"), nil, "not an auto step")
    local run3, ctx3 = mkAuto(30); R.Begin(run3, ctx3, "a"); ctx3.now = 131; R.AutoSettle(run3, ctx3, "a"); R.Begin(run3, ctx3, "a")
    T.eq(R.TimeLeft(run3, ctx3, "a"), nil, "the retry after an automatic unverified waits for the player")
end)
test("end keeps every result and closes the run", function()
    local run, ctx = mk()
    R.Begin(run, ctx, "b"); R.Verdict(run, ctx, "b", "pass")
    local rev = run.revision
    ctx.now = 200
    T.ok(R.End(run, 200)); T.eq(run.endedAt, 200); T.eq(run.revision, rev + 1)
    T.eq(run.steps.b.verdict, "pass"); T.eq(run.steps.a.verdict, "pending")
    T.eq(R.CurrentId(run), nil, "no step to resume")
    T.eq(R.End(run, 300), false, "a second end changes nothing"); T.eq(run.endedAt, 200)
    local a, err = R.Verdict(run, ctx, "a", "pass")
    T.ok(a == nil and err == "run ended"); T.eq(run.steps.a.verdict, "pending")
    T.eq(R.UndoLast(run, ctx), false); T.eq(R.Undo(run, ctx, "b"), false); T.eq(run.steps.b.verdict, "pass")
    T.eq(R.AutoSettle(run, ctx, "a"), nil)
end)
test("end drops the log snapshots of an open attempt and keeps the attempt", function()
    local run, ctx = mk()
    R.Begin(run, ctx, "a")
    T.ok(run.steps.a.attempts[1].snapshots)
    R.End(run, 200)
    T.eq(#run.steps.a.attempts, 1); T.eq(run.steps.a.attempts[1].snapshots, nil)
end)
test("an attempt records a position only for the log its step checks", function()
    local run, ctx, env = mk()
    ctx.plan.logs.other = { global = "DB", path = "other", format = "strings" }
    env.DB.other = { "x" }
    R.Begin(run, ctx, "a")
    local snaps = run.steps.a.attempts[1].snapshots
    T.ok(snaps.debug and snaps.debug.n == 1 and snaps.debug.tail[1] == "old", "checked log")
    T.eq(snaps.other, nil, "unchecked log")
    R.Begin(run, ctx, "b")
    T.eq(next(run.steps.b.attempts[1].snapshots), nil, "a step with no log check records nothing")
end)
test("an older open attempt with a full snapshot still checks its new lines", function()
    local run, ctx, env = mk()
    R.Begin(run, ctx, "a")
    run.steps.a.attempts[1].snapshots = { debug = { "old" } } -- saved by an earlier version
    env.DB.log[#env.DB.log + 1] = "ok line"
    T.eq(R.Verdict(run, ctx, "a", "pass").verdict, "pass")
end)
test("a saved run without endedAt is not ended", function()
    local run, ctx = mk()
    T.eq(run.endedAt, nil); T.eq(R.CurrentId(run), "a")
    T.ok(R.Verdict(run, ctx, "b", "pass"))
end)
-- Automatic steps with a check that something did not happen: judged when the timeout ends
local function timedPlan(assertion)
    local plan = { kind = "plan", ct = 1, addon = "KeepThat", title = "t", logs = { debug = { global = "DB", path = "log", format = "strings" } },
        sections = { { id = "s", title = "S", steps = { { id = "t", title = "T", action = { kind = "manual", text = "t" }, expect = "e",
            verify = { "assertions" }, auto = true, timeout = 10, assertions = { assertion } } } } } }
    local env = { DB = { log = { "old" } } }
    local ctx = { plan = plan, client = "classic-era", build = "1", character = "X", now = 100, env = env, planDigest = "d" }
    return R.New(ctx), ctx, env
end
test("an automatic step with an absence check waits for its timeout and then passes", function()
    local run, ctx, env = timedPlan({ kind = "log", source = "debug", contains = "boom", absent = true })
    R.Begin(run, ctx, "t")
    env.DB.log[#env.DB.log + 1] = "fine"
    ctx.now = 105; T.eq(R.AutoSettle(run, ctx, "t"), nil, "silence so far: not yet")
    ctx.now = 110
    local a = R.AutoSettle(run, ctx, "t")
    T.eq(a.verdict, "pass"); T.eq(a.by, "auto"); T.eq(a.evidence, "matched")
end)
test("an automatic step with an absence check fails at once when the line appears", function()
    local run, ctx, env = timedPlan({ kind = "log", source = "debug", contains = "boom", absent = true })
    R.Begin(run, ctx, "t")
    env.DB.log[#env.DB.log + 1] = "boom"
    ctx.now = 103
    local a = R.AutoSettle(run, ctx, "t")
    T.eq(a.verdict, "fail"); T.eq(a.by, "auto"); T.eq(a.evidence, "contradicts")
end)
test("a count of exactly two waits, then passes; a third line fails it at once", function()
    local run, ctx, env = timedPlan({ kind = "log", source = "debug", contains = "hit", count = { exactly = 2 } })
    R.Begin(run, ctx, "t")
    env.DB.log[#env.DB.log + 1] = "hit"; env.DB.log[#env.DB.log + 1] = "fine"; env.DB.log[#env.DB.log + 1] = "hit"
    ctx.now = 104; T.eq(R.AutoSettle(run, ctx, "t"), nil, "two so far: more could come")
    env.DB.log[#env.DB.log + 1] = "x"; env.DB.log[#env.DB.log + 1] = "hit"
    ctx.now = 105
    T.eq(R.AutoSettle(run, ctx, "t").verdict, "fail", "a third")
    local run2, ctx2, env2 = timedPlan({ kind = "log", source = "debug", contains = "hit", count = { exactly = 2 } })
    R.Begin(run2, ctx2, "t")
    env2.DB.log[#env2.DB.log + 1] = "hit"; env2.DB.log[#env2.DB.log + 1] = "y"; env2.DB.log[#env2.DB.log + 1] = "hit"
    ctx2.now = 110
    T.eq(R.AutoSettle(run2, ctx2, "t").verdict, "pass", "two at the timeout")
end)
test("the timeout with the evidence missing records unverified, not a pass", function()
    local run, ctx = timedPlan({ kind = "log", source = "debug", contains = "hit", count = { exactly = 1 } })
    R.Begin(run, ctx, "t")
    ctx.now = 110
    T.eq(R.AutoSettle(run, ctx, "t").verdict, "unverified", "one was needed and none came")
end)

finish()
