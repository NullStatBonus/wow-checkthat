local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local function good()
    return { kind = "plan", ct = 1, addon = "KeepThat", title = "t",
        logs = { debug = { global = "G", path = "log", format = "strings" } },
        requirements = { loaded = { text = "loaded" } },
        macros = { { id = "dbg", text = "/kt debug on\n/reload" } },
        sections = { { id = "s1", title = "S", steps = {
            { id = "a.1", title = "A", clients = { "classic-era" }, requires = { "loaded" },
              action = { kind = "secure-macro", macro = "dbg" }, expect = "e", verify = { "player", "assertions" },
              assertions = { { kind = "log", source = "debug", contains = "x" } } },
            { id = "a.2", title = "B", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } },
        } } } }
end
test("plan valid", function() T.eq(#ns.Plan.Validate(good()), 0, table.concat(ns.Plan.Validate(good()), ";")) end)
local function bad(mut, needle)
    local p = good(); mut(p)
    local errs = ns.Plan.Validate(p)
    T.ok(#errs > 0, "expected errors for " .. needle)
    T.ok(table.concat(errs, ";"):find(needle, 1, true), needle .. " not in: " .. table.concat(errs, ";"))
end
test("plan rejects Markdown in display text", function()
    bad(function(p) p.sections[1].steps[2].action.text = "Type `/kt log`." end, "markdown in step a.2")
    bad(function(p) p.sections[1].steps[2].expect = "Press **Pass**." end, "markdown")
    bad(function(p) p.preamble = "Run `x`" end, "markdown in plan")
    local p = good(); p.sections[1].steps[2].expect = "Press |cffffd100Pass|r."
    T.eq(#ns.Plan.Validate(p), 0, "native color codes are fine")
end)
test("plan rejects duplicate id", function() bad(function(p) p.sections[1].steps[2].id = "a.1" end, "duplicate") end)
test("plan rejects unknown action kind", function() bad(function(p) p.sections[1].steps[2].action.kind = "cast" end, "unknown action") end)
test("plan rejects unresolved requirement", function() bad(function(p) p.sections[1].steps[1].requires = { "zzz" } end, "unresolved") end)
test("plan rejects unknown probe", function()
    bad(function(p) p.sections[1].steps[1].assertions = { { kind = "state", probe = "cast", op = "eq" } } end, "unknown probe")
end)
test("plan rejects executable macro bodies", function()
    bad(function(p) p.macros[1].text = "/run print(1)" end, "macro not allowed")
    bad(function(p) p.macros[1].text = "/cast Fireball" end, "macro not allowed")
    bad(function(p) p.macros[1].text = "/console scriptErrors 1\n/script x=1" end, "macro not allowed")
end)
test("unknown addon name is named in the error, not blamed on the macro", function()
    local p = good(); p.addon = "WoWCheckThat"
    local errs = ns.Plan.Validate(p)
    T.eq(#errs, 1); T.ok(errs[1]:find("addon not supported") and errs[1]:find("WoWCheckThat"), errs[1])
end)
test("plan cannot extend the slash allow list", function()
    bad(function(p) p.slash = { "/run" }; p.macros[1].text = "/run x" end, "macro not allowed")
end)
test("plan rejects macro from another addon", function()
    bad(function(p) p.macros[1].text = "/ddt debug on" end, "macro not allowed")
end)
test("plan verify/assertions consistency", function()
    bad(function(p) p.sections[1].steps[1].assertions = nil end, "none given")
    bad(function(p) p.sections[1].steps[2].assertions = { { kind = "log", source = "debug", contains = "x" } } end, "lacks")
end)
test("plan validates share values", function()
    local p = good(); p.sections[1].steps[2].share = "export"
    T.eq(#ns.Plan.Validate(p), 0)
    bad(function(q) q.sections[1].steps[2].share = "mail" end, "bad share")
end)
test("plan filters steps by client", function()
    local steps, skipped = ns.Plan.Steps(good(), "forever-camelot")
    T.eq(#steps, 1); T.eq(#skipped, 1); T.eq(steps[1].step.id, "a.2")
end)

test("plan rejects Markdown in the title, labels and requirement text", function()
    bad(function(p) p.title = "Run `x`" end, "markdown in plan title")
    bad(function(p) p.requirements.loaded.text = "needs **it**" end, "markdown in requirement")
    bad(function(p) p.sections[1].steps[1].assertions[1].label = "Check `x`" end, "markdown in step a.1 label")
end)
test("malformed plan shapes are errors, not Lua errors", function()
    bad(function(p) p.sections[1].steps = nil end, "section without a steps list")
    bad(function(p) p.sections[1] = "x" end, "section without a steps list")
    bad(function(p) p.sections[1].steps[2] = 5 end, "step is not a table")
end)

local function auto(p)
    local st = p.sections[1].steps[1]
    st.verify = { "assertions" }; st.auto = true
    return st
end
test("auto step with a required line is valid; timeout 5 to 300 is valid", function()
    local p = good(); auto(p)
    T.eq(#ns.Plan.Validate(p), 0, table.concat(ns.Plan.Validate(p), ";"))
    for _, n in ipairs({ 5, 30, 300 }) do
        p.sections[1].steps[1].timeout = n
        T.eq(#ns.Plan.Validate(p), 0, "timeout " .. n)
    end
end)
test("auto step must verify by assertions alone", function()
    bad(function(p) auto(p).verify = { "player", "assertions" } end, "auto step cannot ask the player")
    bad(function(p) local s = auto(p); s.verify = { "reviewer" }; s.reviewer = "r"; s.assertions = nil end, "auto step needs assertions")
end)
test("auto step needs a required assertion", function()
    bad(function(p) auto(p).assertions[1].diagnostic = true end, "auto step needs a required assertion")
end)
test("auto step may use a check that something did not happen, with a timeout", function()
    local msg = "auto step needs a timeout for a check that is judged at the end"
    bad(function(p) auto(p).assertions[1].absent = true end, msg)
    bad(function(p) auto(p).assertions[1] = { kind = "log", source = "debug", contains = "x", count = { exactly = 2 } } end, msg)
    bad(function(p) auto(p).assertions[1] = { kind = "log", source = "debug", contains = "x", count = { max = 2 } } end, msg)
    for _, a in ipairs({ { kind = "log", source = "debug", contains = "x", absent = true },
        { kind = "log", source = "debug", contains = "x", count = { exactly = 2 } },
        { kind = "log", source = "debug", contains = "x", count = { max = 2 } } }) do
        local p = good(); local s = auto(p); s.assertions[1] = a; s.timeout = 30
        T.eq(#ns.Plan.Validate(p), 0, table.concat(ns.Plan.Validate(p), ";"))
    end
    local p = good(); local s = auto(p); s.assertions[1] = { kind = "log", source = "debug", contains = "x", count = { min = 2 } }
    T.eq(#ns.Plan.Validate(p), 0, "a lower bound needs no timeout")
    local q = good(); local s2 = auto(q)
    s2.assertions[2] = { kind = "log", source = "debug", contains = "y", absent = true, diagnostic = true }
    T.eq(#ns.Plan.Validate(q), 0, "a diagnostic absence check is fine without a timeout")
end)
test("timeout is a whole number from 5 to 300 and only on an auto step", function()
    for _, n in ipairs({ 3, 4, 301, 600, 7.5, -1 }) do
        bad(function(p) auto(p).timeout = n end, "timeout must be a whole number from 5 to 300")
    end
    bad(function(p) auto(p).timeout = "30" end, "timeout must be a whole number from 5 to 300")
    bad(function(p) p.sections[1].steps[1].timeout = 30 end, "timeout needs auto")
    bad(function(p) auto(p).auto = "yes" end, "auto must be boolean")
end)
test("wait-event is valid only on an auto step", function()
    bad(function(p) p.sections[1].steps[1].action = { kind = "wait-event", text = "t" } end, "wait-event needs an auto step")
    local p = good(); auto(p).action = { kind = "wait-event", text = "t" }
    T.eq(#ns.Plan.Validate(p), 0, table.concat(ns.Plan.Validate(p), ";"))
end)
test("assertion flags must be real booleans, so an import cannot downgrade a required check", function()
    bad(function(p) p.sections[1].steps[1].assertions[1].diagnostic = "false" end, "diagnostic must be boolean")
    bad(function(p) p.sections[1].steps[1].assertions[1].absent = "no" end, "absent must be boolean")
    local p = good(); p.sections[1].steps[1].assertions[1].diagnostic = false
    T.eq(#ns.Plan.Validate(p), 0)
end)test("plans for CheckThat allow /ct and /checkthat and no other command", function()
    for _, cmd in ipairs({ "/ct", "/checkthat" }) do
        local p = good(); p.addon = "CheckThat"; p.macros[1].text = cmd .. " debug on\n/reload"
        T.eq(#ns.Plan.Validate(p), 0, cmd .. ": " .. table.concat(ns.Plan.Validate(p), ";"))
    end
    for _, cmd in ipairs({ "/kt debug on", "/ct2 debug on" }) do
        local p = good(); p.addon = "CheckThat"; p.macros[1].text = cmd
        T.ok(#ns.Plan.Validate(p) > 0, cmd .. " must be rejected")
    end
end)

-- Categories
local function cat(p)
    p.categories = { { id = "one", title = "One" }, { id = "two", title = "Two", intro = "i" } }
    p.sections[1].category = "one"
    p.sections[1].steps[2].category = "two"
    return p
end
test("a plan without categories uses each section as one", function()
    local cats, declared = ns.Plan.Categories(good())
    T.eq(#cats, 1); T.eq(cats[1].id, "s1"); T.eq(declared, false)
    local steps = ns.Plan.Steps(good(), "classic-era")
    T.eq(steps[1].category, "s1"); T.eq(steps[2].category, "s1")
end)
test("declared categories resolve from the step, then the section", function()
    local p = cat(good())
    T.eq(#ns.Plan.Validate(p), 0, table.concat(ns.Plan.Validate(p), ";"))
    local cats, declared = ns.Plan.Categories(p)
    T.eq(#cats, 2); T.eq(declared, true)
    local steps = ns.Plan.Steps(p, "classic-era")
    T.eq(steps[1].category, "one"); T.eq(steps[2].category, "two")
end)
test("failed is reserved for /ct rerun failed", function()
    bad(function(p) p.categories = { { id = "failed", title = "F" } }; p.sections[1].category = "failed"; p.sections[1].steps[2].category = "failed" end, "category id failed is reserved")
    bad(function(p) p.sections[1].id = "failed" end, "section id failed is reserved")
    bad(function(p) p.sections[1].id = "Failed" end, "section id failed is reserved")
end)
test("a category id the plan does not declare fails and names the step", function()
    bad(function(p) cat(p); p.sections[1].steps[1].category = "nope" end, "step a.1: unknown category nope")
    bad(function(p) cat(p); p.sections[1].category = "nope" end, "section s1: unknown category nope")
    bad(function(p) p.sections[1].steps[1].category = "one" end, "unknown category one")
end)
test("a step in no category fails when the plan declares categories", function()
    bad(function(p) cat(p); p.sections[1].category = nil; p.sections[1].steps[1].category = nil end, "step a.1: no category")
end)
test("category declarations are checked", function()
    bad(function(p) cat(p); p.categories[2].id = "one" end, "duplicate category id one")
    bad(function(p) cat(p); p.categories[1].id = "Bad Id" end, "category id is not valid")
    bad(function(p) cat(p); p.categories[1].title = nil end, "category one: title missing")
    bad(function(p) cat(p); p.categories[1].title = "Run `x`" end, "markdown in category one")
    bad(function(p) p.categories = {} end, "categories must be a non-empty list")
end)
test("cases must be expanded before a plan reaches the runner", function()
    bad(function(p) p.sections[1].steps[2].cases = { { id = "x", vars = {} } } end, "step a.2: cases must be expanded")
end)

-- Unit-test assertions
local function with(a)
    local p = good()
    p.logs.facts = { global = "G", path = "facts", format = "strings", quiet = true }
    p.sections[1].steps[1].assertions = { a }
    return p
end
local function badA(a, needle)
    local errs = ns.Plan.Validate(with(a))
    T.ok(#errs > 0, "expected errors for " .. needle)
    T.ok(table.concat(errs, ";"):find(needle, 1, true), needle .. " not in: " .. table.concat(errs, ";"))
end
local function fact(extra)
    local a = { kind = "fact", source = "facts", addon = "KeepThat", key = "level", op = "eq", value = 3 }
    for k, v in pairs(extra or {}) do a[k] = v end
    return a
end
test("fact assertions accept every operator with the right value shape", function()
    for _, a in ipairs({
        fact(), fact({ op = "ne" }), fact({ op = "gt" }), fact({ op = "ge" }), fact({ op = "lt" }), fact({ op = "le" }),
        fact({ op = "between", value = { 1, 5 } }), fact({ op = "approx", value = 0.5, tolerance = 0.01 }),
        fact({ op = "in", value = { "a", "b" } }), fact({ op = "matches", value = "^a" }), fact({ op = "contains", value = "a" }),
        fact({ op = "type", value = "number" }), fact({ op = "exists", value = nil }), fact({ op = "missing", value = nil }),
        fact({ which = "any" }), fact({ which = "all", count = { min = 1 } }),
    }) do
        local errs = ns.Plan.Validate(with(a))
        T.eq(#errs, 0, a.op .. ": " .. table.concat(errs, ";"))
    end
end)
test("fact assertions reject a value of the wrong shape", function()
    badA(fact({ op = "between", value = { 1 } }), "between needs a value of two numbers")
    badA(fact({ op = "between", value = { 5, 1 } }), "between needs a value of two numbers")
    badA(fact({ op = "in", value = 3 }), "in needs a value that is a list")
    badA(fact({ op = "approx", value = 0.5 }), "approx needs a tolerance")
    badA(fact({ op = "approx", value = "x", tolerance = 1 }), "approx needs a number value")
    badA(fact({ op = "type", value = "table" }), "type needs number, boolean or string")
    badA(fact({ op = "matches", value = ("x"):rep(201) }), "matches needs a pattern")
    badA(fact({ op = "ge", value = "3" }), "ge needs a number value")
    badA(fact({ op = "near" }), "unknown op near")
    badA(fact({ tolerance = 1 }), "tolerance belongs to approx")
end)
test("fact assertions need a source, an addon, a key and a known which", function()
    badA(fact({ source = "nope" }), "unknown log source nope")
    badA(fact({ addon = false }), "fact needs an addon")
    badA(fact({ key = "" }), "fact needs a key")
    badA(fact({ which = "most" }), "which must be last, any or all")
end)
test("count is a table of whole numbers that agree", function()
    local ok = fact({ count = { exactly = 2 } })
    T.eq(#ns.Plan.Validate(with(ok)), 0)
    local logA = { kind = "log", source = "facts", contains = "x", count = { min = 1, max = 3 } }
    T.eq(#ns.Plan.Validate(with(logA)), 0, table.concat(ns.Plan.Validate(with(logA)), ";"))
    badA(fact({ count = { exactly = 2, min = 1 } }), "exactly cannot combine")
    badA(fact({ count = { min = 3, max = 1 } }), "min is above max")
    badA(fact({ count = { exactly = 1.5 } }), "must be a whole number from 0 to 1000")
    badA(fact({ count = { exactly = 1001 } }), "must be a whole number from 0 to 1000")
    badA(fact({ count = {} }), "count needs exactly, min or max")
    badA(fact({ count = { most = 2 } }), "unknown count field most")
    badA(fact({ count = 2 }), "count must be a table")
    badA({ kind = "log", source = "facts", contains = "x", absent = true, count = { exactly = 0 } }, "count cannot combine with absent")
end)
test("a log source cap is a whole number from 1 to 100000", function()
    for _, v in ipairs({ 0, -1, 1.5, 100001, "100", true }) do
        local p = good(); p.logs.debug.cap = v
        T.ok(table.concat(ns.Plan.Validate(p), ";"):find("cap must be a whole number from 1 to 100000", 1, true), tostring(v))
    end
    local p = good(); p.logs.debug.cap = 100
    T.eq(#ns.Plan.Validate(p), 0)
end)
test("quiet must be a boolean and state assertions take the new operators", function()
    local p = good(); p.logs.debug.quiet = "yes"
    T.ok(table.concat(ns.Plan.Validate(p), ";"):find("log source debug: quiet must be boolean", 1, true))
    for _, a in ipairs({
        { kind = "state", probe = "global-value", name = "G", path = "x", op = "between", value = { 1, 5 } },
        { kind = "state", probe = "global-value", name = "G", path = "x", op = "approx", value = 1, tolerance = 0.1 },
        { kind = "state", probe = "global-value", name = "G", path = "x", op = "missing" },
    }) do T.eq(#ns.Plan.Validate(with(a)), 0, a.op .. ": " .. table.concat(ns.Plan.Validate(with(a)), ";")) end
    badA({ kind = "state", probe = "global-value", name = "G", op = "between", value = 3 }, "between needs a value of two numbers")
end)

test("count is refused on assertions that cannot count, so an import cannot crash the card", function()
    badA({ kind = "state", probe = "global-value", name = "G", op = "exists", count = true }, "count does not apply to state")
    badA({ kind = "log-sequence", source = "facts", sequence = { { contains = "x" } }, count = { min = 1 } }, "count does not apply to log-sequence")
end)
test("section ids must exist and be unique, as the fallback category ids", function()
    bad(function(p) p.sections[1].id = nil end, "section without an id")
    bad(function(p) p.sections[2] = { id = "s1", title = "T", steps = { { id = "z.1", title = "Z", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } } } } end, "duplicate section id s1")
end)

test("an auto step with a required fact missing check needs a timeout", function()
    local p = with(fact({ op = "missing", value = nil }))
    local st = p.sections[1].steps[1]; st.verify = { "assertions" }; st.auto = true
    T.ok(table.concat(ns.Plan.Validate(p), ";"):find("needs a timeout for a check that is judged at the end", 1, true))
    st.timeout = 20
    T.eq(#ns.Plan.Validate(p), 0, table.concat(ns.Plan.Validate(p), ";"))
end)

finish()
