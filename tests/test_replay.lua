local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.stubClient({ toc = 16000 })
H.plain(ns)
local Replay = dofile("tests/replay.lua")

local function step(id, extra)
    local s = { id = id, title = id, action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end
local function log(line, label) return { kind = "log", source = "debug", equals = line, scope = "attempt", label = label or line } end
local function plan(steps)
    return assert(ns.Codec.Encode({ ct = 1, kind = "plan", addon = "CheckThat", title = "t",
        logs = { debug = { global = "CheckThatDB", path = "global.log.entries", format = "entries", cap = 300 } },
        sections = { { id = "s", title = "S", steps = steps } } }))
end
local function has(list, text)
    for _, t in ipairs(list) do if t:find(text, 1, true) then return true end end
    return false
end
local function fresh() ns.App.db = nil end

test("the 0.17 plan replays with no problem", function()
    local f = io.open("build/checkthat-0.17.ct", "rb"); local s = f:read("*a"); f:close()
    local out = Replay.run(ns, s, { hooks = dofile("tests/replay/checkthat-0.17.lua") })
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    T.eq(#out.trace, 20)
end)

test("the 0.20 plan replays with no problem", function()
    local f = io.open("build/checkthat-0.20.ct", "rb"); local s = f:read("*a"); f:close()
    local out = Replay.run(ns, s)
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    T.eq(#out.trace, 16)
end)

test("a step that asserts its own result line is a problem", function()
    local out = Replay.run(ns, plan({ step("a", { verify = { "assertions" }, assertions = { log("[ct] step a pass") } }) }))
    T.ok(has(out.problems, "asserts the line its own result writes"), "named")
    T.ok(has(out.problems, "unverified"), "and the press leaves it unverified")
end)

test("an automatic step that never settles is a problem", function()
    local out = Replay.run(ns, plan({ step("a", { auto = true, timeout = 10, verify = { "assertions" },
        assertions = { { kind = "log", source = "debug", equals = "[ct] never written", absent = false, scope = "attempt", label = "x", diagnostic = false, } } }) }), { hooks = { action = { a = function() end } } })
    T.ok(has(out.problems, "has no result after its action"), table.concat(out.problems, "; "))
end)

test("checks the replay can write settle an automatic step and a manual one", function()
    local out = Replay.run(ns, plan({
        step("a", { auto = true, timeout = 10, verify = { "assertions" }, assertions = { log("[ct] one") } }),
        step("b", { verify = { "assertions" }, assertions = { log("[ct] two") } }) }))
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    T.eq(out.trace[1], "a                    pass (auto)")
end)

test("a step the card shows twice is a warning, unless the hooks say it is meant", function()
    local steps = { step("a"), step("b") }
    local seen = false
    local hook = function(R) if not seen then seen = true; assert(R.App.Undo()) else R.press() end end
    local out = Replay.run(ns, plan(steps), { hooks = { action = { b = hook } } })
    T.ok(has(out.warnings, "a: the card shows this step a second time"), table.concat(out.warnings, "; "))
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    seen = false
    local again = Replay.run(ns, plan(steps), { hooks = { revisits = { a = true, b = true }, action = { b = hook } } })
    T.eq(#again.warnings, 0, table.concat(again.warnings, "; "))
end)

test("an automatic step whose checks are never met is a problem", function()
    local out = Replay.run(ns, plan({ step("a", { auto = true, verify = { "assertions" }, assertions = { log("never has no ct prefix") } }) }))
    T.ok(has(out.problems, "a: the automatic step did not settle"), table.concat(out.problems, "; "))
    T.ok(has(out.warnings, "does not come from CheckThat"), "and the replay says why")
end)

test("a step that was never reached is a problem", function()
    local out = Replay.run(ns, plan({ step("a"), step("b") }), { hooks = { action = { a = function(R) R.press(); R.App.End() end } } })
    T.ok(has(out.problems, "b: never reached"), table.concat(out.problems, "; "))
end)
finish()
