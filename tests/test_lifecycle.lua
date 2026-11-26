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

finish()
