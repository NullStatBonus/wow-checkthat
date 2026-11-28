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

-- A string a Lua pattern matches: the shortest sample made from its literals and classes. nil when it cannot build one.
local function oneOf(tok) -- a character the single class or set `tok` matches
    local ok, found = pcall(function()
        for b = 33, 126 do
            local c = string.char(b)
            if c:find("^" .. tok .. "$") then return c end
        end
        if (" "):find("^" .. tok .. "$") then return " " end
    end)
    return ok and found or nil
end
local function sample(pat)
    local out, i, n = {}, 1, #pat
    while i <= n do
        local c, piece = pat:sub(i, i), nil
        if c == "^" and i == 1 then i = i + 1; goto continue end
        if c == "$" and i == n then i = i + 1; goto continue end
        if c == "%" then
            local e = pat:sub(i + 1, i + 1)
            if e == "" or e == "b" or e == "f" or e:match("%d") then return nil end
            if e:match("%a") then piece = oneOf("%" .. e) else piece = e end
            if not piece then return nil end
            i = i + 2
        elseif c == "[" then
            local j = i + 1
            if pat:sub(j, j) == "^" then j = j + 1 end
            if pat:sub(j, j) == "]" then j = j + 1 end
            while j <= n and pat:sub(j, j) ~= "]" do
                if pat:sub(j, j) == "%" then j = j + 1 end
                j = j + 1
            end
            if j > n then return nil end
            piece = oneOf(pat:sub(i, j))
            if not piece then return nil end
            i = j + 1
        elseif c == "." then piece = "x"; i = i + 1
        elseif c:match("[%(%)]") then i = i + 1; goto continue
        else piece = c; i = i + 1 end
        do
            local q = pat:sub(i, i)
            if q == "+" then i = i + 1 elseif q == "*" or q == "-" or q == "?" then i = i + 1; piece = "" end
            out[#out + 1] = piece
        end
        ::continue::
    end
    local s = table.concat(out)
    local ok, hit = pcall(string.find, s, pat)
    return ok and hit and s or nil
end
Replay.sample = sample

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
    local loadedAddon -- the addon the plan is for: its addon-loaded check must pass
    local env = { time = function() return clock end, GetBuildInfo = function() return "1.0", "1", "x", opts.interface or 16000 end,
        UnitName = function() return "Replay" end, GetRealmName = function() return "R" end,
        IsAddOnLoaded = function(n) return n == "CheckThat" or n == loadedAddon end, CheckThat = ns.Facts.API() }
    local db = {}
    env.CheckThatDB = { global = db }
    App.Init(db, env)
    local imported, err = App.ImportPlan(planString)
    if not imported then problem("the plan did not import: " .. tostring(err)); return out end
    loadedAddon = imported.addon
    -- A plan's own log source (not CheckThat's debug log): make its list before the run starts, so the log is readable
    -- when the run saves its start positions and when a step opens.
    local function sourceList(src)
        local node = env[src.global]; if node == nil then node = {}; env[src.global] = node end
        for p in src.path:gmatch("[^.]+") do node[p] = node[p] or {}; node = node[p] end
        return node
    end
    for _, src in pairs(imported.logs or {}) do
        if src.global and src.global ~= "CheckThatDB" and src.path then sourceList(src) end
    end
    -- hooks.unmet names requirements the replay treats as not met, so a step they make inapplicable takes that branch.
    -- Installed before the run starts, so the judge at run start sees it too.
    local realUnmet = ns.Run.Unmet
    if hooks.unmet then
        ns.Run.Unmet = function(ctx, step)
            for _, r in ipairs(step and step.requires or {}) do
                local def = ctx.plan.requirements and ctx.plan.requirements[r]
                if hooks.unmet[r] and def and def.unmet == "inapplicable" then return def.text or r end
            end
            return realUnmet(ctx, step)
        end
    end

    local run = App.Start(opts.addon or imported.addon or "CheckThat")
    if not run then ns.Run.Unmet = realUnmet; problem("the run did not start"); return out end
    db.log.enabled = true

    local R = { App = App, ns = ns, env = env } -- env: the fake game, for a hook that writes a log line itself
    local _, ctx0 = App.Current()
    local assumed = {}
    -- Write what the step's checks need: the debug lines and facts a tester's actions would produce.
    -- Writes one line for a check; true when it went into a plan's own log source (evidence the replay made up).
    local function writeLine(step, a, source, text)
        local src = ctx0.plan.logs and ctx0.plan.logs[source]
        local own = source == "debug" and (not src or src.global == "CheckThatDB")
        if not text then warn(step.id .. ": evidence not derived, cannot write the check \"" .. tostring(a.label) .. "\" (" .. tostring(source) .. " source, no literal line). Add a hook")
        elseif own and a.equals and not text:find("^%[ct%] ") then warn(step.id .. ": the line \"" .. text .. "\" does not come from CheckThat")
        elseif text:find("[ct] step " .. step.id .. " ", 1, true) == 1 then -- its own result line: nothing can write it first
        elseif own then App.Log((text:gsub("^%[ct%] ", "")))
        elseif src and src.global and src.path then
            local list = sourceList(src)
            list[#list + 1] = src.format == "entries" and { msg = text } or text
            local cap = tonumber(src.cap)
            while cap and #list > cap do table.remove(list, 1) end
            return true
        else warn(step.id .. ": evidence not derived, no log source named " .. tostring(source)) end
    end
    local function lineOf(a) return a.equals or a.contains or (a.pattern and sample(a.pattern)) end
    function R.feed(step)
        for _, a in ipairs(step.assertions or {}) do
            local c = type(a.count) == "table" and a.count or nil
            local none = c and (c.exactly == 0 or c.max == 0) -- "must not appear": write nothing
            if not a.diagnostic and not a.absent and a.op ~= "missing" and not none then
                local made = false
                if a.kind == "log" then
                    for _ = 1, math.max(1, c and (c.exactly or c.min) or 1) do made = writeLine(step, a, a.source, lineOf(a)) or made end
                elseif a.kind == "log-sequence" and a.sequence then
                    for _, item in ipairs(a.sequence) do made = writeLine(step, a, a.source, lineOf(item)) or made end
                elseif a.kind == "fact" then
                    local value = factValue(a)
                    clock = clock + 2
                    if value == nil or not ns.Facts.Report(a.addon, a.key, value) then warn(step.id .. ": cannot report the fact " .. tostring(a.key))
                    elseif a.addon ~= "CheckThat" then made = true end
                else
                    warn(step.id .. ": cannot write a " .. tostring(a.kind) .. " check")
                end
                if made then assumed[#assumed + 1] = step.id end
            end
        end
    end
    function R.press(verdict) return App.Verdict(verdict or "pass") end

    -- A step must not assert the line its own result writes: the result is judged before that line exists.
    local _, ctx = App.Current()
    for _, sec in ipairs(ctx.plan.sections) do
        for _, st in ipairs(sec.steps) do
            for _, a in ipairs(st.assertions or {}) do
                -- Only CheckThat's own debug log gets the result line; another source (the Lua errors) never does.
                local src = ctx.plan.logs and ctx.plan.logs[a.source]
                local debugLog = not src or (src.global == "CheckThatDB" and src.path == "global.log.entries")
                local text = debugLog and (a.equals or a.contains)
                if text and text:find("[ct] step " .. st.id .. " ", 1, true) == 1 then
                    problem(st.id .. ": asserts the line its own result writes (" .. text .. "). The result is judged before the line exists")
                elseif debugLog and a.pattern then
                    for _, v in ipairs({ "pass", "partial", "fail", "skip" }) do
                        local ok, hit = pcall(string.find, "[ct] step " .. st.id .. " " .. v, a.pattern)
                        if ok and hit then
                            problem(st.id .. ": the pattern \"" .. a.pattern .. "\" matches the line its own result writes. The result is judged before the line exists")
                            break
                        end
                    end
                end
            end
        end
    end

    -- Async steps: an addon writes its startup lines before the tester starts a run, so the replay writes them first and
    -- CheckThat judges the steps again, as at the start of a run. A step that passes is never shown.
    local _, actx = App.Current()
    local anyAsync = false
    for _, id in ipairs(run.order) do
        local st = ns.Run.stepOf(actx, id)
        if st and st.async and st.auto and run.steps[id].verdict == "pending" then R.feed(st); anyAsync = true end
    end
    if anyAsync then App.JudgeAtStart(run, actx) end
    for _, id in ipairs(run.order) do
        local a = run.steps[id].attempts[1]
        if a and a.at == "start" then out.trace[#out.trace + 1] = ("%-20s %s (at run start)"):format(id, tostring(a.verdict)) end
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
        if run.steps[step.id].verdict == "inapplicable" then
            out.trace[#out.trace + 1] = ("%-20s inapplicable (%s)"):format(step.id, tostring(run.steps[step.id].unmet))
            goto continue
        end
        local custom = (hooks.action or {})[step.id]
        if custom then
            custom(R)
        elseif step.auto then
            R.feed(step)
            if step.reload == "after_action" then -- the tester's /reload after the action
                App.MarkReloaded()
            end
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
        if rec and rec.verdict == "fail" and not custom and (hooks.verdict or {})[step.id] ~= "fail" then
            problem(step.id .. ": the step failed although the replay did what its checks need (" .. tostring(last and last.outcomes and last.outcomes[1] and last.outcomes[1].why) .. ")")
        end
        out.trace[#out.trace + 1] = ("%-20s %s%s"):format(step.id, tostring(rec and rec.verdict), last and last.by == "auto" and " (auto)" or "")
        local _, _, nxt = App.Current()
        if nxt and nxt.id == step.id and not (rec and rec.verdict and rec.verdict ~= "pending") then
            problem(step.id .. ": has no result after its action, so the card stays on it"); break
        end
        ::continue::
    end
    ns.Run.Unmet = realUnmet

    if #assumed > 0 then
        out.warnings[#out.warnings + 1] = "evidence assumed: the replay made up the lines and facts that " .. #assumed .. " check(s) look for in the plan's own log source. It proves the plan flow, not that the addon writes them"
    end
    for _, id in ipairs(run.order) do
        local rec = run.steps[id]
        local v = rec and rec.verdict
        if not v or v == "pending" then problem(id .. ": never reached") end
    end
    return out
end

return Replay
