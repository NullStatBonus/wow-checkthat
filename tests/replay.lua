-- Plays a compiled plan through the fake client: the plan's own steps, one after the other, the way a tester would.
-- It finds plan mistakes before a tester does: a step that cannot get a result, an automatic step that never settles,
-- a step that asserts the log line its own result writes, a step the card shows more than once, a step never reached.
--
--   local Replay = dofile("tests/replay.lua")
--   local out = Replay.run(ns, planString, { toc = "CheckThat/CheckThat_Camelot.toc", hooks = {...} })
--   out.problems, out.warnings, out.trace   (lists of text)
--
-- hooks.verdict[stepId] = "partial" | "fail" | "skip"   the result to press (default pass)
-- hooks.action[stepId]  = function(R) ... end            does what the step asks instead of the default; R.App, R.ns,
--                                                        R.feed(step), R.press(verdict) and R.step are available
-- hooks.revisits[stepId] = true                          the card shows this step again on purpose, and its text covers it
local Replay = {}

local function tocVersion(path)
    local f = io.open(path); if not f then return "0.0.0" end
    local text = f:read("*a"); f:close()
    return text:match("## Version:%s*([%w%.%-]+)") or "0.0.0"
end

-- A value that satisfies a fact operator.
local function factValue(a)
    local v, op = a.value, a.op
    if op == "ge" or op == "le" or op == "eq" or op == "approx" or op == "contains" or op == "matches" then return v
    elseif op == "gt" then return v + 1 elseif op == "lt" then return v - 1
    elseif op == "ne" then return type(v) == "number" and v + 1 or tostring(v) .. "x"
    elseif op == "between" then return v[1]
    elseif op == "in" then return v[1]
    elseif op == "type" then return ({ number = 1, string = "x", boolean = true })[v]
    elseif op == "exists" then return 1 end
end

function Replay.run(ns, planString, opts)
    opts = opts or {}
    local hooks = opts.hooks or {}
    local App = ns.App
    local out = { problems = {}, warnings = {}, trace = {} }
    local function problem(text) out.problems[#out.problems + 1] = text end
    local function warn(text) out.warnings[#out.warnings + 1] = text end

    local clock = 7000
    ns.version = opts.version or tocVersion(opts.toc or "CheckThat/CheckThat_Camelot.toc")
    local env = { time = function() return clock end, GetBuildInfo = function() return "1.0", "1", "x", opts.interface or 16000 end,
        UnitName = function() return "Replay" end, GetRealmName = function() return "R" end,
        IsAddOnLoaded = function(n) return n == "CheckThat" end, CheckThat = ns.Facts.API() }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    local imported, err = App.ImportPlan(planString)
    if not imported then problem("the plan did not import: " .. tostring(err)); return out end
    local run = App.Start(opts.addon or imported.addon or "CheckThat")
    if not run then problem("the run did not start"); return out end
    db.log.enabled = true

    local R = { App = App, ns = ns }
    -- Write what the step's checks need: the debug lines and facts a tester's actions would produce.
    function R.feed(step)
        for _, a in ipairs(step.assertions or {}) do
            if not a.diagnostic and not a.absent and a.op ~= "missing" then
                if a.kind == "log" then
                    local text = a.equals or a.contains
                    if a.source ~= "debug" or not text then warn(step.id .. ": cannot write the check \"" .. tostring(a.label) .. "\" (source " .. tostring(a.source) .. ")")
                    elseif a.equals and not text:find("^%[ct%] ") then warn(step.id .. ": the line \"" .. text .. "\" does not come from CheckThat")
                    elseif text:find("[ct] step " .. step.id .. " ", 1, true) == 1 then -- its own result line: nothing can write it first
                    else App.Log((text:gsub("^%[ct%] ", ""))) end
                elseif a.kind == "fact" then
                    local value = factValue(a)
                    clock = clock + 2
                    if value == nil or not ns.Facts.Report(a.addon, a.key, value) then warn(step.id .. ": cannot report the fact " .. tostring(a.key)) end
                else
                    warn(step.id .. ": cannot write a " .. tostring(a.kind) .. " check")
                end
            end
        end
    end
    function R.press(verdict) return App.Verdict(verdict or "pass") end

    -- A step must not assert the line its own result writes: the result is judged before that line exists.
    local _, ctx = App.Current()
    for _, sec in ipairs(ctx.plan.sections) do
        for _, st in ipairs(sec.steps) do
            for _, a in ipairs(st.assertions or {}) do
                local text = a.equals or a.contains
                if text and text:find("[ct] step " .. st.id .. " ", 1, true) == 1 then
                    problem(st.id .. ": asserts the line its own result writes (" .. text .. "). The result is judged before the line exists")
                end
            end
        end
    end

    local visits, guard = {}, 0
    while true do
        guard = guard + 1
        if guard > 6 * #run.order + 20 then problem("the replay did not finish: the card keeps cycling"); break end
        local _, _, step = App.Current()
        if not step then break end
        visits[step.id] = (visits[step.id] or 0) + 1
        if visits[step.id] == 2 and not (hooks.revisits or {})[step.id] then
            warn(step.id .. ": the card shows this step a second time. Check that its text covers both visits")
        end
        if visits[step.id] > 3 then problem(step.id .. ": the card keeps coming back to this step"); break end
        App.Begin()
        R.step = step
        local custom = (hooks.action or {})[step.id]
        if custom then
            custom(R)
        elseif step.auto then
            R.feed(step)
            local a = App.AutoSettle()
            if not a and step.timeout then clock = clock + step.timeout + 1; a = App.AutoSettle() end
            if not a then problem(step.id .. ": the automatic step did not settle") end
        else
            R.feed(step)
            local want = (hooks.verdict or {})[step.id] or "pass"
            local a, why = R.press(want)
            if not a then problem(step.id .. ": the " .. want .. " press was refused: " .. tostring(why)) end
        end
        local rec = run.steps[step.id]
        local last = rec and rec.attempts[#rec.attempts]
        if last and last.verdict == "unverified" then
            problem(step.id .. ": the result is unverified, so the card stays on the step (" .. tostring(last.outcomes and last.outcomes[1] and last.outcomes[1].why) .. ")")
        end
        out.trace[#out.trace + 1] = ("%-20s %s%s"):format(step.id, tostring(rec and rec.verdict), last and last.by == "auto" and " (auto)" or "")
        local _, _, nxt = App.Current()
        if nxt and nxt.id == step.id and not (rec and rec.verdict and rec.verdict ~= "pending") then
            problem(step.id .. ": has no result after its action, so the card stays on it"); break
        end
    end

    for _, id in ipairs(run.order) do
        local rec = run.steps[id]
        local v = rec and rec.verdict
        if not v or v == "pending" then problem(id .. ": never reached") end
    end
    return out
end

return Replay
