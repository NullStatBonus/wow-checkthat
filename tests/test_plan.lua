local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local function good()
    return { kind = "plan", wtt = 1, addon = "KeepThat", title = "t",
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
    local p = good(); p.addon = "WoWTestThat"
    local errs = ns.Plan.Validate(p)
    T.eq(#errs, 1); T.ok(errs[1]:find("addon not supported") and errs[1]:find("WoWTestThat"), errs[1])
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
finish()
