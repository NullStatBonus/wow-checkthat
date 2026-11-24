local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local E = ns.Evidence
local plan = { logs = {
    s = { global = "DB", path = "log", format = "strings" },
    e = { global = "DB", path = "ent", format = "entries" } } }
local function env(lines, ent) return { DB = { log = lines, ent = ent or {} } } end
test("ReadLog strings and entries", function()
    local en = env({ "a", "b" }, { { t = 1, msg = "x" }, { t = 2, msg = "y" } })
    T.eq(#E.ReadLog(plan.logs.s, en), 2)
    T.eq(E.ReadLog(plan.logs.e, en)[2], "y")
    T.ok(E.ReadLog(plan.logs.s, {}) == nil)
end)
test("NewLines handles appends, ring rollover and lost overlap", function()
    T.eq(#E.NewLines({ "a", "b", "c" }, { "a", "b", "c", "d", "e" }), 2)
    T.ok(E.NewLines({ "a", "b", "c" }, { "b", "c", "d" }) == nil, "tail cut by rollover is lost, never guessed")
    T.ok(E.NewLines({ "a", "b", "c" }, { "q", "r" }) == nil, "lost")
    T.eq(#E.NewLines({}, { "a" }), 1)
end)
test("log assertion pass, missing is unverified, absent semantics", function()
    local snaps = { s = { "old" } }
    local en = env({ "old", "[kt] started", "[kt] FAILED: x" })
    T.eq((E.CheckLog({ kind = "log", source = "s", equals = "[kt] started" }, snaps, plan, en)), "pass")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "nope" }, snaps, plan, en)), "unverified")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "FAILED", absent = true }, snaps, plan, en)), "fail")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "zzz", absent = true }, snaps, plan, en)), "pass", "window has new lines")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "old" }, snaps, plan, en)), "unverified", "stale line before attempt")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "old", scope = "session" }, snaps, plan, en)), "pass")
end)
test("repeating startup block: boundary found by position after reload", function()
    local block = { "[blizzard] started", "[merchant] started", "[stock] FAILED: no player identity" }
    local before = {}
    for _ = 1, 2 do for _, l in ipairs(block) do before[#before + 1] = l end end
    local after = {}
    for _, l in ipairs(before) do after[#after + 1] = l end
    for _, l in ipairs(block) do after[#after + 1] = l end -- this load's block
    after[#after + 1] = "[kt] new"
    local lines = E.NewLines(before, after)
    T.eq(#lines, 4, "the third block plus the new line are new")
    -- ambiguous after a roll: same tail twice, none at the snapshot length
    T.ok(E.NewLines({ "a", "b", "c" }, { "x", "a", "b", "c", "a", "b", "c", "z" }) == nil, "ambiguous is unverified")
    -- single match after a roll is accepted
    T.eq(#E.NewLines({ "a", "b", "c" }, { "x", "y", "a", "b", "c", "q" }), 1)
end)
test("absent needs a non-empty window", function()
    local en = env({ "old" })
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "FAILED", absent = true }, { s = { "old" } }, plan, en)), "unverified")
end)
test("unreadable log is unverified", function()
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "x" }, {}, plan, {})), "unverified")
end)
test("sequence needs order", function()
    local en = env({ "off", "on 5" })
    local a = { kind = "log-sequence", source = "s", scope = "session", sequence = { { contains = "off" }, { pattern = "^on %d+" } } }
    T.eq((E.CheckSequence(a, {}, plan, en)), "pass")
    a.sequence = { { pattern = "^on" }, { contains = "off" } }
    T.eq((E.CheckSequence(a, {}, plan, en)), "unverified")
end)
test("state probes are closed and read-only", function()
    local en = { DB = { x = { y = 3 } }, IsAddOnLoaded = function(n) return n == "KT" end }
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "DB", path = "x.y", op = "gt", value = 2 }, en)), "pass")
    T.eq((E.CheckState({ kind = "state", probe = "addon-loaded", name = "KT", op = "eq", value = true }, en)), "pass")
    T.eq((E.CheckState({ kind = "state", probe = "addon-loaded", name = "ZZ", op = "eq", value = true }, en)), "fail")
    T.eq((E.CheckState({ kind = "state", probe = "run-code", op = "eq" }, en)), "unverified")
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "DB", path = "nope", op = "gt", value = 1 }, en)), "unverified")
end)
test("an unavailable probe is unverified, never false", function()
    local en = {}
    T.eq((E.CheckState({ kind = "state", probe = "addon-loaded", name = "X", op = "eq", value = false }, en)), "unverified")
    T.eq((E.CheckState({ kind = "state", probe = "frame-shown", name = "NoSuchFrame", op = "eq", value = false }, en)), "unverified")
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "DB", path = "x", op = "eq", value = false }, en)), "unverified")
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "DB", op = "exists" }, en)), "fail")
end)
test("preview shows live check states without recording", function()
    local step = { assertions = {
        { kind = "log", source = "s", contains = "hooked", label = "Hooks started" },
        { kind = "log", source = "s", contains = "FAILED", absent = true },
        { kind = "log", source = "s", contains = "never", diagnostic = true } } }
    local snaps = { s = { "old" } }
    local en = env({ "old" })
    local items = E.Preview(step, snaps, plan, en)
    T.eq(#items, 2, "diagnostic checks are not shown")
    T.eq(items[1].state, "waiting"); T.eq(items[1].label, "Hooks started"); T.eq(items[2].state, "later")
    en.DB.log[#en.DB.log + 1] = "[kt] hooked X"
    T.eq(E.Preview(step, snaps, plan, en)[1].state, "met")
    local bad = { assertions = { { kind = "state", probe = "global-value", name = "DB", path = "log.1", op = "eq", value = "zzz" } } }
    T.eq(E.Preview(bad, {}, plan, en)[1].state, "bad")
end)
test("pattern length capped", function()
    local en = env({ "x" })
    T.eq((E.CheckLog({ kind = "log", source = "s", pattern = string.rep("a", 300) }, {}, plan, en)), "unverified")
end)

test("an unreadable log at attempt start is not an empty baseline", function()
    local step = { assertions = { { kind = "log", source = "s", contains = "x" } } }
    local snap = E.Snapshot(plan, {}, step)                 -- addon data missing when the step opened
    T.ok(snap.s.unavailable, "marked unavailable")
    local en = env({ "old startup line" })                  -- later the log exists and holds an old line
    local r, why = E.CheckLog({ kind = "log", source = "s", contains = "old startup" }, snap, plan, en)
    T.eq(r, "unverified"); T.ok(why:find("not readable"), why)
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "old startup", scope = "session" }, snap, plan, en)), "pass")
    local empty = E.Snapshot(plan, env({}), step)           -- a readable empty log is a valid baseline
    T.ok(not empty.s.unavailable)
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "new" }, empty, plan, env({ "new" }))), "pass")
end)
test("a snapshot records only the logs an attempt-scoped assertion checks, as length and tail", function()
    local lines = {}
    for i = 1, 30 do lines[i] = "l" .. i end
    local en = env(lines, { { msg = "e1" } })
    local step = { assertions = {
        { kind = "log", source = "s", contains = "x" },
        { kind = "log-sequence", source = "s", sequence = { { contains = "a" } } },
        { kind = "log", source = "e", contains = "y", scope = "session" },
        { kind = "state", probe = "addon-loaded", name = "X", op = "eq", value = true } } }
    local snap = E.Snapshot(plan, en, step)
    T.ok(snap.s, "checked log recorded"); T.eq(snap.e, nil, "session scope needs no position")
    T.eq(snap.s.n, 30); T.eq(#snap.s.tail, E.TAIL); T.eq(snap.s.tail[1], "l19"); T.eq(snap.s.tail[E.TAIL], "l30")
    T.eq(next(E.Snapshot(plan, en, { assertions = {} })), nil, "a step with no log check records nothing")
    T.eq(next(E.Snapshot(plan, en)), nil, "no step, nothing recorded")
    en.DB.log[31] = "new"
    local r = E.CheckLog({ kind = "log", source = "s", equals = "new" }, snap, plan, en)
    T.eq(r, "pass", "new lines are found from the tail")
    T.eq((E.CheckLog({ kind = "log", source = "s", equals = "l30" }, snap, plan, en)), "unverified", "old lines stay old")
end)
test("NewLines reads a position record and an older full snapshot alike", function()
    local cur = { "a", "b", "c", "d", "e" }
    T.eq(#E.NewLines({ n = 3, tail = { "a", "b", "c" } }, cur), 2)
    T.eq(#E.NewLines({ "a", "b", "c" }, cur), 2, "saved before positions existed")
    T.eq(#E.NewLines({ n = 0, tail = {} }, cur), 5, "empty log at the start")
    T.ok(E.NewLines({ n = 3, tail = { "q", "r", "s" } }, cur) == nil, "lost position is never guessed")
end)
test("an attempt with positions but none for the source is unverified, not all new", function()
    local en = env({ "old", "match" })
    local a = { kind = "log", source = "s", contains = "match" }
    local r, why = E.CheckLog(a, {}, plan, en)
    T.eq(r, "unverified"); T.ok(why:find("position missing"), why)
    local r2, why2 = E.CheckSequence({ kind = "log-sequence", source = "s", sequence = { { contains = "match" } } }, {}, plan, en)
    T.eq(r2, "unverified"); T.ok(why2:find("position missing"), why2)
    T.eq((E.CheckLog(a, nil, plan, en)), "pass", "no attempt at all: live view reads the whole log")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "match", scope = "session" }, {}, plan, en)), "pass")
end)
test("after a ring roll an absence cannot be shown, but a present line still fails and a match still passes", function()
    local ring = {}
    for i = 1, 14 do ring[i] = "tick" end
    local snap = E.Snapshot(plan, env(ring), { assertions = { { kind = "log", source = "s", contains = "x" } } })
    -- the ring holds 14 lines: "forbidden", 12 ticks and "ok" pushed 13 old lines out
    local cur = { "forbidden" }
    for _ = 1, 12 do cur[#cur + 1] = "tick" end
    cur[#cur + 1] = "ok"
    local lines, exact = E.NewLines(snap.s, cur)
    T.eq(#lines, 1, "the boundary looks unique, so only 'ok' is new"); T.eq(exact, false, "but the boundary was found by search")
    local en = env(cur)
    local absent = { kind = "log", source = "s", contains = "forbidden", absent = true }
    local r, why = E.CheckLog(absent, snap, plan, en)
    T.eq(r, "unverified", "the missed line must not pass an absence check"); T.ok(why:find("cannot be shown"), why)
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "ok" }, snap, plan, en)), "pass", "a present line still passes")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "ok", absent = true }, snap, plan, en)), "fail", "a present line still fails an absence check")
    local _, exact2 = E.NewLines({ "a", "b" }, { "a", "b", "c" }); T.eq(exact2, true, "an unrolled log is exact")
    T.eq(select(2, E.NewLines(nil, { "a" })), true); T.eq(select(2, E.NewLines({ n = 0, tail = {} }, { "a" })), true)
end)
test("a full ring rolls with every line; a distinctive tail still gives an exact boundary", function()
    local ring = {}
    for i = 1, 300 do ring[i] = "line " .. i end
    local snap = E.Snapshot(plan, env(ring), { assertions = { { kind = "log", source = "s", contains = "x" } } })
    local cur = {}
    for i = 6, 300 do cur[#cur + 1] = "line " .. i end            -- five old lines rolled out
    for _, l in ipairs({ "status requested", "run opened x" }) do cur[#cur + 1] = l end
    local lines, exact = E.NewLines(snap.s, cur)
    T.eq(#lines, 2); T.eq(exact, true, "the tail is distinctive, so nothing is missing")
    local en = env(cur)
    local absent = { kind = "log", source = "s", contains = "run pruned", absent = true }
    T.eq((E.CheckLog(absent, snap, plan, en)), "pass", "an absence is shown on a full ring")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "run opened", absent = true }, snap, plan, en)), "fail")
    local flood = {}
    for i = 1, 300 do flood[i] = "tick" end
    local snap2 = E.Snapshot(plan, env(flood), { assertions = { { kind = "log", source = "s", contains = "x" } } })
    local _, exact2 = E.NewLines(snap2.s, flood)
    T.eq(exact2, false, "a tail of one repeated line proves no boundary")
end)
test("state probe keeps a stored false", function()
    local en = { DB = { flags = { on = false } } }
    local a = { kind = "state", probe = "global-value", name = "DB", path = "flags.on", op = "eq", value = false }
    T.eq((E.CheckState(a, en)), "pass")
    a.path = "flags.missing"
    T.eq((E.CheckState(a, en)), "unverified", "a missing field stays unavailable")
end)
test("frame probe survives a throwing frame", function()
    local en = setmetatable({}, { __index = function() error("boom") end })
    local a = { kind = "state", probe = "frame-shown", name = "X", op = "eq", value = true }
    T.eq((E.CheckState(a, en)), "unverified")
    en = { X = { IsShown = function() error("boom") end } }
    T.eq((E.CheckState(a, en)), "unverified")
end)

-- Typed facts, counts and quiet sources
local fplan = { logs = {
    f = { global = "DB", path = "facts", format = "strings" },
    q = { global = "DB", path = "errors", format = "strings", quiet = true } } }
local function fenv(facts, errors) return { DB = { facts = facts, errors = errors or {} } } end
local function fact(extra)
    local a = { kind = "fact", source = "f", addon = "KT", key = "level", op = "eq", value = 3 }
    for k, v in pairs(extra or {}) do a[k] = v end
    return a
end
local function snapOf(a, en) return E.Snapshot(fplan, en, { assertions = { a } }) end
local function judge(a, before, after, errsBefore, errsAfter)
    local snaps = snapOf(a, fenv(before, errsBefore))
    return E.CheckFact(a, snaps, fplan, fenv(after, errsAfter)) 
end
test("ParseValue reads booleans, numbers and text", function()
    T.eq(E.ParseValue("true"), true); T.eq(E.ParseValue("false"), false)
    T.eq(E.ParseValue("3"), 3); T.eq(E.ParseValue("-0.5"), -0.5); T.eq(E.ParseValue("1e+20"), 1e20); T.eq(E.ParseValue(".5"), 0.5)
    T.eq(E.ParseValue("abc"), "abc"); T.eq(E.ParseValue("0x10"), "0x10"); T.eq(E.ParseValue("nan"), "nan"); T.eq(E.ParseValue(""), "")
    local a, k, v = E.ParseFact("[KT] level=5")
    T.eq(a, "KT"); T.eq(k, "level"); T.eq(v, 5)
    T.ok(E.ParseFact("not a fact") == nil)
end)
test("fact comparisons pass and fail on the parsed value", function()
    T.eq((judge(fact(), {}, { "[KT] level=3" })), "pass")
    T.eq((judge(fact(), {}, { "[KT] level=4" })), "fail")
    T.eq((judge(fact({ op = "between", value = { 1, 5 } }), {}, { "[KT] level=9" })), "fail", "out of range contradicts")
    T.eq((judge(fact({ op = "between", value = { 1, 5 } }), {}, { "[KT] level=5" })), "pass", "ends are inside")
    T.eq((judge(fact({ op = "ge", value = 3 }), {}, { "[KT] level=3" })), "pass")
    T.eq((judge(fact({ op = "le", value = 2 }), {}, { "[KT] level=3" })), "fail")
    T.eq((judge(fact({ op = "approx", value = 0.5, tolerance = 0.01 }), {}, { "[KT] level=0.504" })), "pass")
    T.eq((judge(fact({ op = "approx", value = 0.5, tolerance = 0.01 }), {}, { "[KT] level=0.52" })), "fail")
    T.eq((judge(fact({ op = "type", value = "number" }), {}, { "[KT] level=abc" })), "fail")
    T.eq((judge(fact({ op = "type", value = "boolean" }), {}, { "[KT] level=false" })), "pass")
    T.eq((judge(fact({ op = "in", value = { "a", "b" } }), {}, { "[KT] level=b" })), "pass")
    T.eq((judge(fact({ op = "in", value = { "a", "b" } }), {}, { "[KT] level=c" })), "fail")
    T.eq((judge(fact({ op = "matches", value = "^ab" }), {}, { "[KT] level=abc" })), "pass")
    T.eq((judge(fact({ op = "matches", value = "(" }), {}, { "[KT] level=abc" })), "fail", "a bad pattern never raises")
    T.eq((judge(fact({ op = "contains", value = "bc" }), {}, { "[KT] level=abc" })), "pass")
    T.eq((judge(fact({ op = "exists", value = nil }), {}, { "[KT] level=1" })), "pass")
end)
test("a fact that never arrives is unverified, and other facts do not count", function()
    T.eq((judge(fact(), {}, {})), "unverified")
    T.eq((judge(fact(), {}, { "[KT] other=3", "[DDT] level=3" })), "unverified", "same key from another addon, other key")
    T.eq((judge(fact(), { "[KT] level=3" }, { "[KT] level=3" })), "unverified", "a fact from before the step opened is old")
end)
test("which picks the last, any or all facts", function()
    local after = { "[KT] level=1", "[KT] level=3", "[KT] level=9" }
    T.eq((judge(fact(), {}, after)), "fail", "last is 9")
    T.eq((judge(fact({ which = "any" }), {}, after)), "pass")
    T.eq((judge(fact({ which = "all", op = "ge", value = 1 }), {}, after)), "pass")
    T.eq((judge(fact({ which = "all", op = "le", value = 5 }), {}, after)), "fail")
    T.eq((judge(fact({ which = "any", value = 7 }), {}, after)), "fail", "facts arrived and none match")
end)
test("missing passes when no fact arrived and fails when one did", function()
    T.eq((judge(fact({ op = "missing", value = nil }), { "[KT] x=1" }, { "[KT] x=1", "[KT] y=1" })), "pass")
    T.eq((judge(fact({ op = "missing", value = nil }), { "[KT] x=1" }, { "[KT] x=1", "[KT] level=1" })), "fail")
    T.eq((judge(fact({ op = "missing", value = nil }), {}, {})), "unverified", "a log with no new lines may be off")
end)
test("count judges how many matched", function()
    local two = fact({ op = "exists", value = nil, count = { exactly = 2 } })
    T.eq((judge(two, {}, { "[KT] level=1", "[KT] level=2" })), "pass")
    T.eq((judge(two, {}, { "[KT] level=1", "[KT] level=2", "[KT] level=3" })), "fail", "too many contradicts")
    T.eq((judge(two, {}, { "[KT] level=1" })), "unverified", "one may still arrive")
    local atLeast = fact({ op = "exists", value = nil, count = { min = 2 } })
    T.eq((judge(atLeast, {}, { "[KT] level=1" })), "unverified")
    T.eq((judge(atLeast, {}, { "[KT] level=1", "[KT] level=1", "[KT] level=1" })), "pass")
    local ranged = fact({ op = "gt", value = 2, count = { min = 1, max = 2 } })
    T.eq((judge(ranged, {}, { "[KT] level=1", "[KT] level=5" })), "pass", "only values that pass the operator count")
    local logCount = { kind = "log", source = "f", contains = "hit", count = { exactly = 2 } }
    local snaps = snapOf(logCount, fenv({}))
    T.eq((E.CheckLog(logCount, snaps, fplan, fenv({ "hit", "hit" }))), "pass")
    T.eq((E.CheckLog(logCount, snaps, fplan, fenv({ "hit", "hit", "hit" }))), "fail")
    T.eq((E.CheckLog(logCount, snaps, fplan, fenv({ "hit" }))), "unverified")
end)
test("a count of zero needs a log that can show it", function()
    local none = { kind = "log", source = "f", contains = "boom", count = { exactly = 0 } }
    T.eq((E.CheckLog(none, snapOf(none, fenv({ "old" })), fplan, fenv({ "old", "fine" }))), "pass", "new lines, no match")
    T.eq((E.CheckLog(none, snapOf(none, fenv({ "old" })), fplan, fenv({ "old" }))), "unverified", "no new lines: debug may be off")
    T.eq((E.CheckLog(none, snapOf(none, fenv({ "old" })), fplan, fenv({ "old", "boom" }))), "fail")
    T.eq((E.CheckLog(none, {}, fplan, {})), "unverified", "unreadable")
end)
test("silence on a quiet source passes an absence or a zero count", function()
    local absent = { kind = "log", source = "q", pattern = ".", absent = true }
    local en0 = fenv({}, {})
    T.eq((E.CheckLog(absent, snapOf(absent, en0), fplan, fenv({}, {}))), "pass", "no new error lines")
    T.eq((E.CheckLog(absent, snapOf(absent, en0), fplan, fenv({}, { "boom" }))), "fail")
    local zero = { kind = "log", source = "q", pattern = ".", count = { exactly = 0 } }
    T.eq((E.CheckLog(zero, snapOf(zero, en0), fplan, fenv({}, {}))), "pass")
    T.eq((E.CheckLog(zero, snapOf(zero, en0), fplan, fenv({}, { "boom" }))), "fail")
    local expected = { kind = "log", source = "q", contains = "boom" }
    T.eq((E.CheckLog(expected, snapOf(expected, en0), fplan, fenv({}, { "x: boom" }))), "pass", "an expected error")
    T.eq((E.CheckLog(absent, snapOf(absent, en0), fplan, {})), "unverified", "an unreadable source stays unverified")
end)
test("state probes take the new operators and missing needs a readable table", function()
    local en = { DB = { n = 4, s = "abc", t = { x = 1 } } }
    local function st(extra) local a = { kind = "state", probe = "global-value", name = "DB", path = "n", op = "eq", value = 4 }; for k, v in pairs(extra) do a[k] = v end; return a end
    T.eq((E.CheckState(st({ op = "between", value = { 1, 5 } }), en)), "pass")
    T.eq((E.CheckState(st({ op = "between", value = { 5, 9 } }), en)), "fail")
    T.eq((E.CheckState(st({ op = "approx", value = 4.1, tolerance = 0.2 }), en)), "pass")
    T.eq((E.CheckState(st({ path = "s", op = "type", value = "string" }), en)), "pass")
    T.eq((E.CheckState(st({ path = "s", op = "matches", value = "^a" }), en)), "pass")
    T.eq((E.CheckState(st({ op = "in", value = { 3, 4 } }), en)), "pass")
    T.eq((E.CheckState(st({ op = "ge", value = 4 }), en)), "pass")
    T.eq((E.CheckState(st({ path = "nope", op = "missing", value = nil }), en)), "pass")
    T.eq((E.CheckState(st({ op = "missing", value = nil }), en)), "fail")
    T.eq((E.CheckState(st({ name = "Gone", path = "n", op = "missing", value = nil }), en)), "unverified", "no such global is not a missing field")
end)
test("the evidence operators are the plan's operators", function()
    for op in pairs(ns.Plan.OPS) do T.ok(E.Ops[op], "no evidence operator for " .. op) end
    for op in pairs(E.Ops) do T.ok(ns.Plan.OPS[op], "plan does not allow " .. op) end
end)
test("a bounded log below its cap has never rolled, so its boundary is exact even when the lines are alike", function()
    local same = {}
    for i = 1, 5 do same[i] = "boom" end
    local snap = { n = 5, tail = same }
    local cur = {}; for i = 1, 5 do cur[i] = "boom" end
    cur[6] = "new"
    local _, exact = E.NewLines(snap, cur)
    T.eq(exact, false, "no cap: a tail of the same line proves nothing")
    local lines, exact2 = E.NewLines(snap, cur, 100)
    T.eq(exact2, true, "under the cap"); T.eq(#lines, 1)
    local full = {}; for i = 1, 100 do full[i] = "boom" end
    local _, exact3 = E.NewLines({ n = 100, tail = full }, full, 100)
    T.eq(exact3, false, "a full log may have dropped lines")
end)
test("an absence check on a capped quiet source passes over old lines that are all alike", function()
    local p = { logs = { q = { global = "DB", path = "errors", format = "strings", quiet = true, cap = 100 } } }
    local a = { kind = "log", source = "q", pattern = ".", absent = true }
    local env = { DB = { errors = { "same", "same", "same" } } }
    local snaps = E.Snapshot(p, env, { assertions = { a } })
    T.eq((E.CheckLog(a, snaps, p, env)), "pass", "nothing new since the step opened")
    env.DB.errors[4] = "different"
    T.eq((E.CheckLog(a, snaps, p, env)), "fail")
    p.logs.q.cap = nil
    env.DB.errors[4] = nil
    T.eq((E.CheckLog(a, snaps, p, env)), "unverified", "without the cap it stays unverified")
end)
test("an upper-bound count stays pending on the card until the verdict", function()
    local a = fact({ op = "exists", value = nil, count = { exactly = 1 } })
    local items = E.Preview({ assertions = { a } }, nil, fplan, fenv({ "[KT] level=1" }))
    T.eq(items[1].state, "later")
    a.count = { min = 1 }
    items = E.Preview({ assertions = { a } }, snapOf(a, fenv({})), fplan, fenv({ "[KT] level=1" }))
    T.eq(items[1].state, "met")
end)
test("a check that is judged at the verdict shows bad as soon as it can no longer pass", function()
    local a = fact({ op = "exists", value = nil, count = { exactly = 1 } })
    local snaps = snapOf(a, fenv({}))
    T.eq(E.Preview({ assertions = { a } }, snaps, fplan, fenv({ "[KT] level=1" }))[1].state, "later", "one so far: it may be right")
    T.eq(E.Preview({ assertions = { a } }, snaps, fplan, fenv({ "[KT] level=1", "[KT] level=2" }))[1].state, "bad", "two: too many, for good")
    local none = { kind = "log", source = "f", contains = "boom", absent = true }
    local s2 = snapOf(none, fenv({ "old" }))
    T.eq(E.Preview({ assertions = { none } }, s2, fplan, fenv({ "old", "fine" }))[1].state, "later")
    T.eq(E.Preview({ assertions = { none } }, s2, fplan, fenv({ "old", "boom" }))[1].state, "bad")
end)

test("an exact count is not shown on a log whose boundary is uncertain, but too many still fails", function()
    local flood = {}
    for i = 1, 300 do flood[i] = "tick" end
    local a = { kind = "log", source = "f", contains = "hit", count = { exactly = 1 } }
    local snaps = E.Snapshot(fplan, fenv(flood), { assertions = { a } })
    local after = {}; for i, l in ipairs(flood) do after[i] = l end
    after[#after + 1] = "hit"
    T.eq((E.CheckLog(a, snaps, fplan, fenv(after))), "unverified", "a rolled log may have hidden a second hit")
    after[#after + 1] = "hit"
    T.eq((E.CheckLog(a, snaps, fplan, fenv(after))), "fail", "two visible hits are too many whatever was lost")
    local b = { kind = "fact", source = "f", addon = "KT", key = "level", op = "ge", value = 1, which = "all" }
    local fl = {}; for i = 1, 300 do fl[i] = "tick" end
    local bs = E.Snapshot(fplan, fenv(fl), { assertions = { b } })
    local fa = {}; for i, l in ipairs(fl) do fa[i] = l end
    fa[#fa + 1] = "[KT] level=2"
    T.eq((E.CheckFact(b, bs, fplan, fenv(fa))), "unverified", "which all cannot be shown when facts may be lost")
end)
test("a required fact missing check waits until the verdict on the card", function()
    local a = fact({ op = "missing", value = nil })
    local items = E.Preview({ assertions = { a } }, snapOf(a, fenv({})), fplan, fenv({}))
    T.eq(items[1].state, "later")
end)

finish()
