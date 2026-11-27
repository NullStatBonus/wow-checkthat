-- CheckThat through the game's load order (offline level 3): saved variables, login events and /reload. Issue 149.
local ns, test, T, finish = dofile("tests/harness.lua")()
local Runner = dofile("tools/entry_runner.lua")

local function planText()
    local f = assert(io.open("build/keepthat.ct")); local s = f:read("*a"); f:close()
    return s
end

test("a run started before a reload is still the current run after it", function()
    local seen = {}
    local r = Runner.run({ toc = "CheckThat/CheckThat_Vanilla.toc", level = 3, steps = { { reload = true } } }, {
        loaded = function(cns, st, n)
            local app = cns.App
            seen[n] = { enabled = cns.addon and cns.addon:IsEnabled(), db = type(CheckThatDB) }
            if n == 1 then
                T.ok(app.ImportPlan(planText()))
                T.ok(app.Start("KeepThat"))
                seen[1].runId = app.Current().runId
                app.Verdict("pass")
            else
                local run = app.Current()
                seen[2].runId = run and run.runId
                seen[2].results = run and #(run.results or {})
            end
        end,
    })
    T.ok(r.ok, r.steps[#r.steps].detail)
    T.eq(#seen, 2, "two loads")
    T.ok(seen[1].enabled and seen[2].enabled, "the addon is enabled after each login")
    T.eq(seen[2].db, "table")
    T.ok(seen[1].runId, "a run started")
    T.eq(seen[2].runId, seen[1].runId, "the same run is current after the reload")
end)

test("a reload while the card shows a past run marks the open run, and the resume lines name that run", function()
    local ids, seen = {}, {}
    local r = Runner.run({ toc = "CheckThat/CheckThat_Vanilla.toc", level = 3, steps = { { reload = true } } }, {
        loaded = function(cns, st, n)
            local app = cns.App
            if n == 1 then
                T.ok(app.ImportPlan(planText()))
                ids.past = assert(app.Start("KeepThat")).runId
                T.ok(app.End(ids.past))
                ids.open = assert(app.Start("KeepThat")).runId
                T.ok(ids.open ~= ids.past)
                app.Begin() -- the open run has an open attempt on its current step
                T.ok(app.OpenRun(ids.past), "the card shows the past run")
                T.eq(app.Current().runId, ids.past)
                st.said = {}
            else
                local run = app.db.runs[ids.open]
                local rec = run.steps[run.order[run.current]]
                seen.reloaded = rec.attempts[#rec.attempts].reloaded
                seen.said = table.concat(st.said, "\n")
                seen.shown = app.Current().runId
            end
        end,
    })
    T.ok(r.ok, r.steps[#r.steps].detail)
    T.eq(seen.shown, ids.past, "the card still shows the past run")
    T.eq(seen.reloaded, true, "the open run's attempt is marked as reloaded")
    T.ok(seen.said:find("Reloaded. Your run continues on the same step.", 1, true), seen.said)
    T.ok(seen.said:find(ids.open .. ": ", 1, true), "the status line names the open run: " .. seen.said)
    T.ok(not seen.said:find("(run ended)", 1, true), "the past run is not reported as resumed: " .. seen.said)
end)

test("a second level 3 run in the same process loads CheckThat again", function()
    local r = Runner.run({ toc = "CheckThat/CheckThat_Vanilla.toc", level = 3, steps = { { reload = true } } })
    T.ok(r.ok, r.steps[#r.steps].detail)
end)

finish()
