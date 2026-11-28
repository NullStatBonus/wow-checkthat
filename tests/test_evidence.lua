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
    -- ambiguous after a roll: same tail twice, none at the snapshot length. The last match is taken and not exact.
    local amb, ex = E.NewLines({ "a", "b", "c" }, { "x", "a", "b", "c", "a", "b", "c", "z" })
    T.eq(#amb, 1); T.eq(ex, false, "a repeated run leaves an inexact boundary")
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

test("money probe reads the balance, and an unreadable balance is unverified, never a guess", function()
    local rich = { GetMoney = function() return 12345 end }
    T.eq((E.CheckState({ kind = "state", probe = "money", op = "ge", value = 10000 }, rich)), "pass")
    local r, _, d = E.CheckState({ kind = "state", probe = "money", op = "eq", value = 0 }, rich, true)
    T.eq(r, "fail")
    T.eq(d.observed, nil, "the player's money is personal: a failed check does not save the amount")
    local a = { kind = "state", probe = "money", op = "eq", value = 0 }
    T.eq((E.CheckState(a, {})), "unverified", "no GetMoney")
    T.eq((E.CheckState(a, { GetMoney = function() error("boom") end })), "unverified", "a raising read")
    T.eq((E.CheckState(a, { GetMoney = function() return nil end })), "unverified", "a missing answer (a secret value reads nil in the adapter)")
end)

test("a game read that answers nothing is unverified with every operator, exists too", function()
    for _, a in ipairs({ { probe = "money" }, { probe = "bag-free-slots" }, { probe = "item-count", id = 6948 }, { probe = "frame-text", name = "F" } }) do
        a.kind, a.op = "state", "exists"
        T.eq((E.CheckState(a, {})), "unverified", a.probe .. " exists with no answer")
    end
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "Nope", op = "exists" }, {})), "fail", "a global that is not there still fails exists")
end)
test("a failed money check saves no amount, and the saved rule names the item or bag", function()
    local _, _, d = E.CheckState({ kind = "state", probe = "money", op = "ge", value = 100 }, { GetMoney = function() return 12345 end }, true)
    T.eq(d.observed, nil, "the player's money is not saved")
    local _, _, d2 = E.CheckState({ kind = "state", probe = "item-count", id = 6948, op = "ge", value = 5 }, { ItemCount = function() return 2 end }, true)
    T.eq(d2.observed, "2", "an item count is saved")
    T.ok(d2.rule:find("id 6948", 1, true), "the rule names the item: " .. tostring(d2.rule))
    local _, _, d3 = E.CheckState({ kind = "state", probe = "bag-free-slots", bag = 2, op = "ge", value = 5 }, { ContainerFreeSlots = function() return 1 end }, true)
    T.ok(d3.rule:find("bag 2", 1, true), "the rule names the bag: " .. tostring(d3.rule))
    local _, _, d4 = E.CheckState({ kind = "state", probe = "money", op = "ge", value = 100 }, { GetMoney = function() return 1 end }, true)
    T.eq(d4.rule, "money ge 100", "no name, no double space")
end)
test("bag-free-slots probe sums bags 0 to 4, or reads the one bag it names", function()
    local env = { ContainerFreeSlots = function(bag) return bag end } -- bag n holds n free slots
    T.eq((E.CheckState({ kind = "state", probe = "bag-free-slots", op = "eq", value = 10 }, env)), "pass", "0+1+2+3+4")
    T.eq((E.CheckState({ kind = "state", probe = "bag-free-slots", bag = 3, op = "eq", value = 3 }, env)), "pass")
    local half = { ContainerFreeSlots = function(bag) if bag == 2 then return nil end return 1 end }
    T.eq((E.CheckState({ kind = "state", probe = "bag-free-slots", op = "ge", value = 0 }, half)), "unverified", "one bag unknown makes the sum unknown")
    T.eq((E.CheckState({ kind = "state", probe = "bag-free-slots", op = "ge", value = 0 }, {})), "unverified", "no such read")
end)

test("item-count probe reads one item by id, and needs an id", function()
    local env = { ItemCount = function(id) return id == 6948 and 5 or 0 end }
    T.eq((E.CheckState({ kind = "state", probe = "item-count", id = 6948, op = "eq", value = 5 }, env)), "pass")
    T.eq((E.CheckState({ kind = "state", probe = "item-count", id = 6948, op = "eq", value = 5 }, {})), "unverified", "no such read")
    T.eq((E.CheckState({ kind = "state", probe = "item-count", op = "eq", value = 0 }, env)), "unverified", "an id is required")
    T.eq((E.CheckState({ kind = "state", probe = "item-count", id = "6948", op = "eq", value = 0 }, env)), "unverified", "an id is a number")
end)

test("frame-text probe reads a frame's text, cut to 80 characters, and never guesses", function()
    local env = { Tip = { GetText = function() return "Bank" end } }
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Tip", op = "eq", value = "Bank" }, env)), "pass")
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Tip", op = "contains", value = "ank" }, env)), "pass")
    local long = { Long = { GetText = function() return string.rep("a", 200) end } }
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Long", op = "eq", value = string.rep("a", 80) }, long)), "pass", "cut to VALUE_LEN")
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Gone", op = "eq", value = "Bank" }, env)), "unverified", "no such frame")
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Bad", op = "eq", value = "x" }, { Bad = { GetText = function() error("boom") end } })), "unverified", "a raising read")
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Num", op = "eq", value = "5" }, { Num = { GetText = function() return 5 end } })), "unverified", "text only")
    local viaAdapter = { FrameText = function(name) return name == "Tip" and string.rep("b", 200) or nil end }
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Tip", op = "eq", value = string.rep("b", 80) }, viaAdapter)), "pass", "the adapter read, cut")
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Gone", op = "eq", value = "x" }, viaAdapter)), "unverified", "the adapter says nil")
    T.eq((E.CheckState({ kind = "state", probe = "frame-text", name = "Tip", op = "eq", value = "x" }, { FrameText = function() error("boom") end })), "unverified", "a raising adapter read")
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
    local bad, why = judge(fact({ op = "matches", value = "(" }), {}, { "[KT] level=abc" })
    T.eq(bad, "unverified", "a bad pattern never raises and never decides")
    T.ok(tostring(why):find("opens a capture it does not close", 1, true), tostring(why))
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
test("a full ring that reads the saved tail again is not exact", function()
    local lines, exact = E.NewLines({ "a", "b", "c" }, { "a", "b", "c" }, 3)
    T.eq(#lines, 0); T.eq(exact, false, "forbidden,a,b,c would look the same")
    local _, exact2 = E.NewLines({ "a", "b", "c" }, { "a", "b", "c" }, 5)
    T.eq(exact2, true, "a log below its cap never dropped a line")
end)
-- Model test: a log that keeps its newest cap lines, with startup blocks that repeat. Whatever NewLines says, the lines it
-- returns must be the end of the true new lines, and exact may be true only when they are all of them.
test("NewLines never claims an exact boundary it cannot prove (ring model)", function()
    local seed = 12345
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n + 1 end
    local blocks = { { "a", "b", "c" }, { "x", "y" }, { "z" } }
    local checked = 0
    for _ = 1, 400 do
        local cap = rnd(8) + 3
        local ring, all = {}, {}
        local function write(l)
            all[#all + 1] = l; ring[#ring + 1] = l
            if #ring > cap then table.remove(ring, 1) end
        end
        for _ = 1, rnd(12) do
            if rnd(3) == 1 then for _, l in ipairs(blocks[rnd(#blocks)]) do write(l) end else write("u" .. rnd(50)) end
        end
        local tail = {}
        for i, l in ipairs(ring) do tail[i] = l end
        local snap = { n = #ring, tail = tail }
        local at = #all
        for _ = 1, rnd(8) - 1 do
            if rnd(3) == 1 then for _, l in ipairs(blocks[rnd(#blocks)]) do write(l) end else write("u" .. rnd(50)) end
        end
        local trueNew = {}
        for i = at + 1, #all do trueNew[#trueNew + 1] = all[i] end
        local got, exact = E.NewLines(snap, ring, cap)
        if got then
            checked = checked + 1
            local off = #trueNew - #got
            local suffix = off >= 0
            if suffix then for i = 1, #got do if got[i] ~= trueNew[off + i] then suffix = false end end end
            T.ok(suffix, "window is the end of the true new lines")
            if exact then T.eq(#got, #trueNew, "exact means every new line is there") end
        end
    end
    T.ok(checked > 100, "the model exercised many windows")
end)
test("which any is unverified, not failed, when the boundary is inexact", function()
    local p = { "[KT] p=1", "[KT] p=2", "[KT] p=3" }
    local after = { "[KT] z=0", p[1], p[2], p[3], "[KT] level=5", p[1], p[2], p[3], "[KT] level=1" }
    T.eq((judge(fact({ which = "any", value = 5 }), p, after)), "unverified", "level=5 may sit before the last tail copy")
    T.eq((judge(fact({ which = "any", value = 1 }), p, after)), "pass", "a match still passes")
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
test("ReadLog gives the entries' times only when every entry has one", function()
    local _, t = E.ReadLog(plan.logs.e, env({}, { { t = 1, msg = "x" }, { t = 2.5, msg = "y" } }))
    T.same(t, { 1, 2.5 })
    T.eq(select(2, E.ReadLog(plan.logs.e, env({}, { { t = 1, msg = "x" }, { msg = "y" } }))), nil, "one without t")
    T.eq(select(2, E.ReadLog(plan.logs.s, env({ "a" }))), nil, "strings have no times")
end)
-- #158: a full ring of { t, msg } entries whose last lines repeat an earlier block. Without times the boundary is
-- inexact and an absence cannot be shown; with times it is found once and exact.
test("a full timed log with repeated blocks still proves an absence (#158)", function()
    local p = { logs = { q = { global = "DB", path = "ent", format = "entries", cap = 30 } } }
    local a = { kind = "log", source = "q", contains = "sold junk", absent = true }
    local ent, clock = {}, 100
    local function write(msg) clock = clock + 1; ent[#ent + 1] = { t = clock, msg = msg }; if #ent > 30 then table.remove(ent, 1) end end
    for _ = 1, 10 do write("merchant opened"); write("scan done"); write("merchant closed") end
    local en = { DB = { ent = ent } }
    local snaps = E.Snapshot(p, en, { assertions = { a } })
    T.eq(#snaps.q.times, E.TAIL, "the position keeps the tail lines' times")
    local runA = { kind = "log", source = "q", contains = "x", scope = "run" }
    local _, runPos = next(E.Snapshot(p, en, { assertions = { runA } }, snaps))
    T.same(runPos.times, snaps.q.times, "a run-scoped copy keeps them")
    write("merchant opened"); write("scan done"); write("merchant closed")
    T.eq((E.CheckLog(a, snaps, p, en)), "pass", "the new block is found after the right place")
    write("sold junk")
    T.eq((E.CheckLog(a, snaps, p, en)), "fail")
    -- the same log and position without times: the repeated block leaves the place open
    local old = { q = { n = snaps.q.n, tail = snaps.q.tail } }
    ent[#ent] = nil
    T.eq((E.CheckLog(a, old, p, en)), "unverified", "a position saved before #158 keeps the old rule")
end)
test("a timed tail that the clock wrote twice is not exact", function()
    local snap = { n = 4, tail = { "a", "b", "c", "x" }, times = { 1, 2, 3, 4 } }
    local cur = { "q", "a", "b", "c", "x", "a", "b", "c", "x", "y" } -- not at position 4 any more: the place is searched
    local lines, exact = E.NewLines(snap, cur, 10, { 0, 1, 2, 3, 4, 1, 2, 3, 4, 5 })
    T.eq(exact, false, "the clock ran back: two places"); T.same(lines, { "y" })
    local one, ex1 = E.NewLines({ n = 3, tail = { "z", "z", "z" }, times = { 7, 7, 7 } }, { "z", "z", "z", "z" }, 4, { 7, 7, 7, 7 })
    T.eq(ex1, false, "a tail written within one tick falls back to the old rules"); T.ok(one ~= nil)
end)
-- The ring model again, with a clock that may stand still between lines: exact must still mean every new line is there.
test("NewLines with times never claims an exact boundary it cannot prove (timed ring model)", function()
    local seed = 777
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n + 1 end
    local blocks = { { "a", "b", "c" }, { "x", "y" }, { "z" } }
    local checked, exacts, untimed = 0, 0, 0
    for _ = 1, 600 do
        local cap = rnd(16) + 3
        local ring, rt, all, clock = {}, {}, {}, 0
        local function write(l)
            if rnd(3) > 1 then clock = clock + 1 end
            all[#all + 1] = l; ring[#ring + 1] = l; rt[#rt + 1] = clock
            if #ring > cap then table.remove(ring, 1); table.remove(rt, 1) end
        end
        local function some(n) for _ = 1, n do if rnd(3) == 1 then for _, l in ipairs(blocks[rnd(#blocks)]) do write(l) end else write("u" .. rnd(4)) end end end
        some(rnd(20))
        local tail, tt = {}, {}
        for i = math.max(1, #ring - E.TAIL + 1), #ring do tail[#tail + 1] = ring[i]; tt[#tt + 1] = rt[i] end
        local snap, at = { n = #ring, tail = tail, times = tt }, #all
        some(rnd(10) - 1)
        local trueNew = {}
        for i = at + 1, #all do trueNew[#trueNew + 1] = all[i] end
        local got, exact = E.NewLines(snap, ring, cap, rt)
        if got then
            checked = checked + 1
            local off = #trueNew - #got
            local suffix = off >= 0
            if suffix then for i = 1, #got do if got[i] ~= trueNew[off + i] then suffix = false end end end
            T.ok(suffix, "window is the end of the true new lines")
            if exact then exacts = exacts + 1; T.eq(#got, #trueNew, "exact means every new line is there") end
            if select(2, E.NewLines({ n = snap.n, tail = tail }, ring, cap)) then untimed = untimed + 1 end
        end
    end
    T.ok(checked > 100, ("the model exercised many windows (%d)"):format(checked))
    T.ok(exacts > untimed + 20, ("times prove more boundaries: %d exact with times, %d without"):format(exacts, untimed))
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

-- A pattern Lua cannot read is never run (Plan.PatternProblem), whatever the plan says. A line that takes the matcher over its step
-- budget (Pattern.BUDGET) is "could not be checked": neither a match nor a miss.
local function judged(a, lines)
    local all = { "old" }
    for _, l in ipairs(lines) do all[#all + 1] = l end
    return E.CheckLog(a, snapOf(a, fenv({ "old" })), fplan, fenv(all))
end
local function spyMatch()
    local real, calls = ns.Pattern.Search, { n = 0 }
    H.stub(ns.Pattern, "Search", function(...) calls.n = calls.n + 1; return real(...) end)
    return calls
end
test("a pattern Lua cannot read is never run: the check is unverified, also for an absence or a count", function()
    ns.Pattern.ClearCache()
    local calls = spyMatch()
    local bad = "(unclosed"
    local en = fenv({ "old" }, { "old" })
    local after = fenv({ "old", "(unclosed text", "more" }, { "old", "x" })
    local function judgeLog(a) return E.CheckLog(a, snapOf(a, en), fplan, after) end
    local r, why = judgeLog({ kind = "log", source = "f", pattern = bad })
    T.eq(r, "unverified"); T.ok(tostring(why):find("opens a capture it does not close", 1, true), tostring(why)); T.ok(tostring(why):find("it was not run", 1, true), tostring(why))
    T.eq((judgeLog({ kind = "log", source = "f", pattern = bad, absent = true })), "unverified", "an absence is not shown by a pattern nobody ran")
    T.eq((judgeLog({ kind = "log", source = "f", pattern = bad, count = { max = 0 } })), "unverified")
    T.eq((judgeLog({ kind = "log", source = "f", pattern = bad, count = { exactly = 1 } })), "unverified")
    local seq = { kind = "log-sequence", source = "f", sequence = { { contains = "old" }, { pattern = bad } } }
    T.eq((E.CheckSequence(seq, snapOf(seq, en), fplan, after)), "unverified")
    local viaFact = fact({ op = "matches", value = bad })
    T.eq((E.CheckFact(viaFact, snapOf(viaFact, en), fplan, fenv({ "old", "[KT] level=abc" }))), "unverified")
    local viaState = { kind = "state", probe = "global-value", name = "DB", path = "s", op = "matches", value = bad }
    T.eq((E.CheckState(viaState, { DB = { s = "abc" } })), "unverified")
    T.eq(E.Ops.matches("(unclosed", bad), false)
    local preview = E.Preview({ assertions = { { kind = "log", source = "f", pattern = bad, absent = true } } }, snapOf({ kind = "log", source = "f", pattern = bad }, en), fplan, after)
    T.eq(preview[1].state, "later", "the card never shows it met")
    T.eq(calls.n, 0, "the matcher never saw it")
end)
test("a pattern that is not text, or a contains or equals that is not, never raises and never decides", function()
    local en = fenv({ "old" })
    for _, p in ipairs({ "(", "%", "[a", 5, "a" .. string.char(0) .. "b" }) do
        local a = { kind = "log", source = "f", pattern = p }
        T.eq((E.CheckLog(a, snapOf(a, en), fplan, fenv({ "old", "a(" }))), "unverified", tostring(p))
    end
    for _, k in ipairs({ "contains", "equals" }) do
        local a = { kind = "log", source = "f", [k] = {} }
        T.eq((E.CheckLog(a, snapOf(a, en), fplan, fenv({ "old", "a" }))), "unverified", k .. " that is not text")
    end
    T.ok(E.ReadLog("x", {}) == nil, "a log source that is not a table reads nothing")
    T.eq((E.CheckLog({ kind = "log", source = "f", contains = "a" }, nil, { logs = { f = "x" } }, fenv({ "a" }))), "unverified")
end)
test("a long line is matched whole: a forbidden line past character 1000 still fails, as before", function()
    local long = string.rep("x", 1100) .. " ERROR boom"
    T.eq((judged({ kind = "log", source = "f", pattern = "ERROR", absent = true }, { long })), "fail", "absent")
    T.eq((judged({ kind = "log", source = "f", pattern = "ERROR", count = { max = 0 } }, { long })), "fail", "count max 0")
    T.eq((judged({ kind = "log", source = "f", pattern = "boom$" }, { long })), "pass", "an end anchor")
    T.eq((judged({ kind = "log", source = "f", pattern = "^x+ ERROR" }, { long })), "pass")
    T.eq((judged({ kind = "log", source = "f", pattern = "ERROR boom" }, { long })), "pass")
    T.eq((judged({ kind = "log", source = "f", pattern = "nothing here", absent = true }, { long })), "pass", "a real absence still passes")
    local viaFact = fact({ op = "matches", value = "boom$" })
    T.eq((E.CheckFact(viaFact, snapOf(viaFact, fenv({})), fplan, fenv({ "[KT] level=" .. long }))), "pass", "a fact value")
    local viaState = { kind = "state", probe = "global-value", name = "DB", path = "s", op = "matches", value = "boom$" }
    T.eq((E.CheckState(viaState, { DB = { s = long } })), "pass", "a state value")
end)
local SET = "[^" .. ("bcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-.,;:!"):sub(1, 70) .. "]"
local SLOW = { ".-.-.-.-Z", "a.-a.-a.-a.-Z", string.rep("%d?", 20) .. " ms", string.rep("a?", 26) .. "b", ".-" .. string.rep("a?", 12) .. "b",
    SET .. "*" .. SET .. "*x", "(%S+)%s+(.+)", "%w+%s*=%s*%d+" }
local function slowLine(p)
    if p:find("%d", 1, true) and p:find(" ms", 1, true) then return string.rep("1", 51) end
    if p:find("a?", 1, true) and not p:find(".-", 1, true) then return string.rep("a", 60) end
    return string.rep("a", 400)
end
test("a line that takes too long is unverified, quickly: never pass and never fail", function()
    local started = os.clock()
    for _, pat in ipairs(SLOW) do
        local line = slowLine(pat)
        local r, why = judged({ kind = "log", source = "f", pattern = pat }, { line })
        T.eq(r, "unverified", pat:sub(1, 20)); T.eq(why, E.TOO_LONG)
        T.eq((judged({ kind = "log", source = "f", pattern = pat, absent = true }, { line })), "unverified", "an absence is not shown")
        T.eq((judged({ kind = "log", source = "f", pattern = pat, count = { max = 0 } }, { line })), "unverified", "at most zero is not shown")
        T.eq((judged({ kind = "log", source = "f", pattern = pat, count = { exactly = 1 } }, { line })), "unverified")
        local seq = { kind = "log-sequence", source = "f", sequence = { { pattern = pat } } }
        local sr, swhy = E.CheckSequence(seq, snapOf(seq, fenv({ "old" })), fplan, fenv({ "old", line }))
        T.eq(sr, "unverified"); T.eq(swhy, E.TOO_LONG)
        local viaFact = fact({ op = "matches", value = pat })
        T.eq((E.CheckFact(viaFact, snapOf(viaFact, fenv({})), fplan, fenv({ "[KT] level=q" .. line }))), "unverified", "a fact value")
        local viaState = { kind = "state", probe = "global-value", name = "DB", path = "s", op = "matches", value = pat }
        T.eq((E.CheckState(viaState, { DB = { s = line } })), "unverified", "a state value")
    end
    T.ok(os.clock() - started < 3, "all of it took " .. (os.clock() - started) .. " s")
end)
test("a pattern that starts with .* or .- is judged exactly even on a flood: the leading repeat is dropped", function()
    local started = os.clock()
    local flood = string.rep("a", 1000)
    for _, pat in ipairs({ ".-" .. string.rep("a", 190) .. "b", ".-%b()", ".*b", "(.*)b" }) do
        local want = string.find(flood, pat) ~= nil
        T.eq((judged({ kind = "log", source = "f", pattern = pat }, { flood })), want and "pass" or "unverified", pat:sub(1, 20))
        T.eq((judged({ kind = "log", source = "f", pattern = pat, absent = true }, { flood })), want and "fail" or "pass", pat:sub(1, 20) .. " absent")
    end
    T.ok(os.clock() - started < 1)
end)
test("a match on another line still passes, and what was shown still fails", function()
    local pat = "a.-a.-a.-a.-Z"
    local flood = string.rep("a", 1000)
    local good = "a1a2a3a4Z"
    T.eq((judged({ kind = "log", source = "f", pattern = pat }, { flood, good })), "pass", "a positive match on another line")
    T.eq((judged({ kind = "log", source = "f", pattern = pat, absent = true }, { flood, good })), "fail", "a forbidden line that was found")
    T.eq((judged({ kind = "log", source = "f", pattern = pat, count = { min = 1 } }, { flood, good })), "pass", "no upper bound")
    T.eq((judged({ kind = "log", source = "f", pattern = pat, count = { max = 1 } }, { flood, good })), "unverified", "it may have matched too")
    T.eq((judged({ kind = "log", source = "f", pattern = pat, count = { max = 1 } }, { flood, good, good })), "fail", "two real matches are too many")
end)
test("old linear patterns judge the same as string.find does, on long ordinary lines too", function()
    local noise = string.rep("the quick brown fox [kt] merchant started: bag 12 of 30 free slots, vendor=Bob level=5 ", 12)
    local pats = { "%d+%.?%d*", "(%S+)%s+(.+)", ".*%d+", ": *.*", "%[(.-)%]%s*(.*)", "%a+%s*%a*", "^%s*(.-)%s*$", "(%d+) (%d+) (%d+) (%d+) (%d+)",
        "%d+:%d+:%d+%.%d+ %a+", "^confirm: bought .+ anyway$", "^(%w+):%s+(%w+)%s.-anyway$", "started.-slots.-Bob" }
    for _, n in ipairs({ 40, 80, 150, 300, 600, 900 }) do
        for _, line in ipairs({ noise:sub(1, n), "confirm: bought " .. noise:sub(1, n) .. " anyway", "confirm: " .. noise:sub(1, n) .. " anyway", "12:34:56.789 PM " .. noise:sub(1, n) }) do
            for _, p in ipairs(pats) do
                local want = string.find(line, p) ~= nil and "pass" or "unverified"
                local got, why = judged({ kind = "log", source = "f", pattern = p }, { line })
                -- a line may be over the budget (for example .*%d+ on a long line without digits): then it is unverified, never a wrong pass
                if got ~= want then T.eq(why, E.TOO_LONG, p .. " on " .. #line .. " characters"); T.eq(want, "pass", "a miss is never turned into a pass") end
                T.ok(got ~= "pass" or want == "pass", p)
            end
        end
    end
end)
test("the card asks again about the same lines: the matcher runs once for each line and pattern", function()
    ns.Pattern.ClearCache()
    local calls = spyMatch()
    local a = { kind = "log", source = "f", pattern = "k.-o.-Z" }
    local lines = {}
    for i = 1, 20 do lines[i] = "kick one two " .. i end
    for _ = 1, 3 do T.eq((judged(a, lines)), "unverified") end
    T.ok(calls.n <= 20, "matcher calls: " .. calls.n)
    local flood = string.rep("a", 1000)
    local slow = { kind = "log", source = "f", pattern = ".-.-.-.-Z" }
    local before = calls.n
    for _ = 1, 3 do T.eq((judged(slow, { flood })), "unverified") end
    T.eq(calls.n - before, 1, "a line that took too long is not tried again")
end)

test("the pass allowance: the first refresh is cut short and unverified 'still checking', a later one settles with the right verdict", function()
    ns.Pattern.ClearCache()
    local keep = ns.Pattern.PASS_ALLOWANCE
    ns.Pattern.PASS_ALLOWANCE = 30000
    local words = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega alpha beta gamma delta"
    local lines = {}
    for i = 1, 200 do lines[i] = words .. " " .. i end
    lines[200] = "last line: x = 5"
    local pat = "%a+%s*=%s*%d+" -- three repeats: the port
    local calls = spyMatch()
    local absent = { kind = "log", source = "f", pattern = pat, absent = true }
    local en = fenv({ "old" })
    local snaps = snapOf(absent, en)
    local after = { "old" }
    for _, l in ipairs(lines) do after[#after + 1] = l end
    local function check() return ns.Pattern.Pass(function() return E.CheckLog(absent, snaps, fplan, fenv(after)) end) end -- the card's pass
    local r1, why1 = check()
    T.eq(r1, "unverified"); T.eq(why1, E.PENDING, "the first refresh could not look at every line")
    T.ok(calls.n < 200, "lines run in the first refresh: " .. calls.n)
    local present = { kind = "log", source = "f", pattern = pat }
    local passes, r, why = 1, r1, why1
    while why == E.PENDING and passes < 30 do passes = passes + 1; r, why = check() end
    T.eq(r, "fail", "the forbidden line is found once every line was seen: " .. tostring(why)); T.ok(passes >= 3, "passes: " .. passes)
    T.eq(calls.n, 200, "each line was run once")
    local before = calls.n
    check(); T.eq(calls.n, before, "a refresh after that costs nothing")
    -- what records a result has no allowance: one call judges every line and never says "still checking"
    ns.Pattern.ClearCache()
    local rr, rwhy = E.Check(absent, snaps, fplan, fenv(after))
    T.eq(rr, "fail", "judging reads the whole log: " .. tostring(rwhy)); T.ok(rwhy ~= E.PENDING)
    ns.Pattern.ClearCache()
    local pv = E.Preview({ assertions = { present = nil, absent } }, snaps, fplan, fenv(after))
    T.eq(pv[1].state, "later", "the live card may be cut short")
    -- a match found settles a presence check at once, even while other lines are pending
    ns.Pattern.ClearCache()
    local early = { "word = 1" }
    for i = 1, 200 do early[#early + 1] = words .. " " .. i end
    T.eq((E.Check(present, snapOf(present, en), fplan, fenv((function() local t = { "old" }; for _, l in ipairs(early) do t[#t + 1] = l end; return t end)()))), "pass")
    ns.Pattern.PASS_ALLOWANCE = keep
end)
test("Preview is one pass, and the card shows an unfinished check as waiting, then settles", function()
    ns.Pattern.ClearCache()
    local keep = ns.Pattern.PASS_ALLOWANCE
    ns.Pattern.PASS_ALLOWANCE = 4000
    local lines = { "old" }
    for i = 1, 150 do lines[#lines + 1] = "gamma delta epsilon " .. i .. " eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau" end
    local a = { kind = "log", source = "f", pattern = "%a+%s*=%s*%d+", absent = true }
    local snaps = snapOf(a, fenv({ "old" }))
    local first = E.Preview({ assertions = { a } }, snaps, fplan, fenv(lines))[1].state
    T.eq(first, "later", "an absence is judged at the verdict")
    local verdict, why = E.Check(a, snaps, fplan, fenv(lines))
    local n = 0
    while why == E.PENDING and n < 40 do n = n + 1; verdict, why = E.Check(a, snaps, fplan, fenv(lines)) end
    T.eq(verdict, "pass", "no line has an equals sign: it settles as a pass")
    ns.Pattern.PASS_ALLOWANCE = keep
end)
test("a fact value that took too long: a value that matched wins for which any, a value that broke it wins for which all", function()
    local flood = string.rep("a", 400)
    local pat = "(%S+)%s+(.+)"
    local function judgeF(which, values)
        local lines = {}
        for i, v in ipairs(values) do lines[i] = "[KT] level=" .. v end
        local a = fact({ op = "matches", value = pat, which = which })
        return E.CheckFact(a, snapOf(a, fenv({})), fplan, fenv(lines))
    end
    T.eq((judgeF("any", { flood, "x y" })), "pass", "a match wins over a value that took too long")
    T.eq((judgeF("any", { "x y", flood })), "pass")
    local r, why = judgeF("any", { flood, "abc" }); T.eq(r, "unverified"); T.eq(why, E.TOO_LONG)
    T.eq((judgeF("all", { flood, "abc" })), "fail", "a value that broke it decides")
    local r2, why2 = judgeF("all", { flood, "x y" }); T.eq(r2, "unverified"); T.eq(why2, E.TOO_LONG)
    local r3 = judgeF("last", { "x y", flood }); T.eq(r3, "unverified")
    T.eq((judgeF("last", { flood, "x y" })), "pass")
    local ca = fact({ op = "matches", value = pat, count = { min = 1 } })
    T.eq((E.CheckFact(ca, snapOf(ca, fenv({})), fplan, fenv({ "[KT] level=" .. flood, "[KT] level=x y" }))), "pass", "a count with no upper bound")
    local cm = fact({ op = "matches", value = pat, count = { max = 1 } })
    T.eq((E.CheckFact(cm, snapOf(cm, fenv({})), fplan, fenv({ "[KT] level=" .. flood, "[KT] level=x y" }))), "unverified", "it may have matched too")
end)

test("a count that is short gives the skip reason when lines were left unchecked, and the saved detail counts them", function()
    ns.Pattern.ClearCache()
    local flood = string.rep("a", 400)
    local pat = "(%S+)%s+(.+)"
    local lines = { "x y", flood, flood, "z w" }
    local a = { kind = "log", source = "f", pattern = pat, count = { min = 3 } }
    local r, why, detail = E.CheckLog(a, snapOf(a, fenv({ "old" })), fplan, (function() local t = { "old" }; for _, l in ipairs(lines) do t[#t + 1] = l end; return fenv(t) end)(), true)
    T.eq(r, "unverified"); T.eq(why, E.TOO_LONG, "2 matched, 3 needed, but 2 lines could not be checked")
    T.eq(detail.matched, 2); T.eq(detail.unchecked, 2, "the saved detail says how many lines were not checked")
    local a2 = { kind = "log", source = "f", pattern = pat, count = { min = 5 } }
    local r2, why2 = E.CheckLog(a2, snapOf(a2, fenv({ "old" })), fplan, fenv({ "old", "x y" }))
    T.eq(r2, "unverified"); T.ok(tostring(why2):find("1 matched, 5 needed", 1, true), "with nothing skipped it says so as before: " .. tostring(why2))
    local seq = { kind = "log-sequence", source = "f", sequence = { { pattern = pat } } }
    local _, _, sd = E.CheckSequence(seq, snapOf(seq, fenv({ "old" })), fplan, fenv({ "old", flood, flood }), true)
    T.eq(sd.unchecked, 2, "a sequence")
    local fa = fact({ op = "matches", value = pat, which = "all" })
    local fr, _, fd = E.CheckFact(fa, snapOf(fa, fenv({})), fplan, fenv({ "[KT] level=ab cd", "[KT] level=" .. flood }), true)
    T.eq(fr, "unverified"); T.eq(fd.unchecked, 1, "a fact")
    local clean = { kind = "log", source = "f", contains = "zzz" }
    local _, _, cd = E.CheckLog(clean, snapOf(clean, fenv({ "old" })), fplan, fenv({ "old", "a" }), true)
    T.eq(cd.unchecked, nil, "nothing unchecked, nothing saved")
end)

finish()
