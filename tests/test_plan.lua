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
test("auto step cannot rely on an absence check", function()
    bad(function(p) auto(p).assertions[1].absent = true end, "auto step cannot use a required absence check")
    local p = good(); local s = auto(p)
    s.assertions[2] = { kind = "log", source = "debug", contains = "y", absent = true, diagnostic = true }
    T.eq(#ns.Plan.Validate(p), 0, "a diagnostic absence check is fine")
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

finish()
