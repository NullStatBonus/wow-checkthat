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
    T.eq(#out.trace, 14)
end)

test("the 0.20.1 plan replays with no problem", function()
    local f = io.open("build/checkthat-0.20.1.ct", "rb"); local s = f:read("*a"); f:close()
    local out = Replay.run(ns, s, { hooks = dofile("tests/replay/checkthat-0.20.1.lua") })
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    T.eq(#out.trace, 9)
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
test("sample builds a line a Lua pattern matches", function()
    for _, pat in ipairs({ "^%[toast%] shown %d+$", "^%[merchant%] tinted [1-9]%d* of %d+ on page %d+$", "^%[toast%] move done at %u+ %-?%d+ %-?%d+$",
        "%[Other%]", "^%[recipes%] recipe probe: x source=.* stale=0 .*mismatches=0 ", "^%[opt%] %a+ on [^x]+$" }) do
        local s = Replay.sample(pat)
        T.ok(s and s:find(pat), pat .. " gave " .. tostring(s))
    end
    T.eq(Replay.sample("%1"), nil, "a back-reference has no sample")
end)

test("a plan that reads another addon's log replays with no hooks and says the evidence is assumed", function()
    local assertions = { { kind = "log", source = "debug", pattern = "^%[toast%] shown %d+$", scope = "attempt", label = "toast" },
        { kind = "log-sequence", source = "debug", scope = "attempt", label = "seq", sequence = { { contains = "first" }, { pattern = "^second %d$" } } } }
    local s = assert(ns.Codec.Encode({ ct = 1, kind = "plan", addon = "KeepThat", title = "t",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings", cap = 300 } },
        sections = { { id = "s", title = "S", steps = { step("a", { auto = true, verify = { "assertions" }, assertions = assertions }) } } } }))
    local out = Replay.run(ns, s)
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    T.ok(has(out.warnings, "evidence assumed"), table.concat(out.warnings, "; "))
end)

local function otherPlan(steps, cap)
    return assert(ns.Codec.Encode({ ct = 1, kind = "plan", addon = "KeepThat", title = "t",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings", cap = cap or 300 },
            facts = { global = "CheckThatDB", path = "global.facts", format = "strings", cap = 300 } },
        sections = { { id = "s", title = "S", steps = steps } } }))
end
local function auto(id, assertions) return step(id, { auto = true, verify = { "assertions" }, timeout = 5, assertions = assertions }) end

test("a step that ends in Fail although the replay did what its checks need is a problem", function()
    local out = Replay.run(ns, otherPlan({ auto("a", { { kind = "log", source = "debug", contains = "x", scope = "attempt", label = "x" },
        { kind = "log", source = "debug", contains = "x", absent = true, scope = "attempt", label = "no x" } }) }))
    T.ok(has(out.problems, "a: the step failed"), table.concat(out.problems, "; "))
end)

test("a run-scoped absence check replays like an attempt-scoped one", function()
    local out = Replay.run(ns, otherPlan({ step("a"), auto("z", { { kind = "log", source = "debug", contains = "ok", scope = "run", label = "ok" },
        { kind = "log", source = "debug", contains = "boom", absent = true, scope = "run", label = "no boom" } }) }))
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
end)

test("an async step passes at run start and is never shown; hooks can make a requirement unmet", function()
    local p = assert(ns.Codec.Encode({ ct = 1, kind = "plan", addon = "KeepThat", title = "t",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings", cap = 300 } },
        requirements = { caster = { text = "This step needs a Mage.", class = { "MAGE" }, unmet = "inapplicable" } },
        sections = { { id = "s", title = "S", steps = {
            step("v", { auto = true, async = true, verify = { "assertions" }, assertions = { { kind = "log", source = "debug", contains = "version 2", label = "v" } } }),
            step("m", { requires = { "caster" } }), step("n") } } } }))
    local out = Replay.run(ns, p, { hooks = { unmet = { caster = true } } })
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    T.ok(has(out.trace, "v                    pass (at run start)"), table.concat(out.trace, " | "))
    T.ok(has(out.trace, "m                    inapplicable (This step needs a Mage.)"), table.concat(out.trace, " | "))
    local both = assert(ns.Codec.Encode({ ct = 1, kind = "plan", addon = "KeepThat", title = "t",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings", cap = 300 } },
        requirements = { caster = { text = "This step needs a Mage.", class = { "MAGE" }, unmet = "inapplicable" } },
        sections = { { id = "s", title = "S", steps = {
            step("v", { requires = { "caster" }, auto = true, async = true, verify = { "assertions" }, assertions = { { kind = "log", source = "debug", contains = "version 2", label = "v" } } }),
            step("n") } } } }))
    local hb = Replay.run(ns, both, { hooks = { unmet = { caster = true } } })
    T.ok(has(hb.trace, "v                    inapplicable"), "an async step the hook makes unmet is not passed at start: " .. table.concat(hb.trace, " | "))
    local plain = Replay.run(ns, p)
    T.ok(has(plain.trace, "m                    pass"), "without the hook the step applies: " .. table.concat(plain.trace, " | "))
end)

test("the 0.21 plan replays with no problem", function()
    local f = io.open("build/checkthat-0.21.ct", "rb"); local s = f:read("*a"); f:close()
    local out = Replay.run(ns, s)
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    T.ok(has(out.trace, "ct2100.start         pass (at run start)"), table.concat(out.trace, " | "))
    local hooked = Replay.run(ns, s, { hooks = { unmet = { mage = true } } })
    T.eq(#hooked.problems, 0, table.concat(hooked.problems, "; "))
    T.ok(has(hooked.trace, "ct2100.mage          inapplicable"), table.concat(hooked.trace, " | "))
end)

test("the plan's own addon counts as loaded", function()
    local out = Replay.run(ns, otherPlan({ auto("a", { { kind = "state", probe = "addon-loaded", name = "KeepThat", op = "eq", value = true, scope = "attempt", label = "loaded" } }) }))
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
end)

test("a fact made up for another addon is reported as assumed", function()
    local out = Replay.run(ns, otherPlan({ auto("a", { { kind = "fact", source = "facts", addon = "KeepThat", key = "k", op = "ge", value = 1, scope = "attempt", label = "k" } }) }))
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
    T.ok(has(out.warnings, "evidence assumed"), table.concat(out.warnings, "; "))
end)

test("a count check gets as many lines as it needs, and none when it must be zero", function()
    local out = Replay.run(ns, otherPlan({ auto("a", { { kind = "log", source = "debug", contains = "x", count = { min = 3 }, scope = "attempt", label = "three" },
        { kind = "log", source = "debug", contains = "y", count = { exactly = 0 }, scope = "attempt", label = "no y" } }) }))
    T.eq(#out.problems, 0, table.concat(out.problems, "; "))
end)

test("the written log keeps to the source's cap", function()
    local seq = { kind = "log-sequence", source = "debug", scope = "attempt", label = "two", sequence = { { contains = "first" }, { contains = "second" } } }
    local out = Replay.run(ns, otherPlan({ auto("a", { seq }), }, 1))
    T.ok(#out.problems > 0, "two lines cannot both sit in a log that holds one")
end)

test("a pattern that matches the step's own result line is a problem", function()
    local out = Replay.run(ns, plan({ step("a", { verify = { "assertions" }, assertions = { { kind = "log", source = "debug", pattern = "^%[ct%] step a %a+$", scope = "session", label = "own" } } }) }))
    T.ok(has(out.problems, "matches the line its own result writes"), table.concat(out.problems, "; "))
end)

test("sample finds a character for a class or set", function()
    for _, pat in ipairs({ "^%P$", "^[^!]$", "^[%]x]$", "^[%a_]+$" }) do
        local s = Replay.sample(pat)
        T.ok(s and s:find(pat), pat .. " gave " .. tostring(s))
    end
    T.eq(Replay.sample("^%z$"), nil)
end)

test("a check with no literal line is reported, not guessed", function()
    local s = assert(ns.Codec.Encode({ ct = 1, kind = "plan", addon = "KeepThat", title = "t",
        logs = { debug = { global = "KeepThatDB", path = "global.log", format = "strings", cap = 300 } },
        sections = { { id = "s", title = "S", steps = { step("a", { auto = true, verify = { "assertions" }, timeout = 5,
            assertions = { { kind = "log", source = "debug", pattern = "%1", scope = "attempt", label = "x" } } }) } } } }))
    local out = Replay.run(ns, s)
    T.ok(has(out.warnings, "evidence not derived"), table.concat(out.warnings, "; "))
end)
finish()
