-- Read-only evidence: addon debug logs and state probes. Never writes to another addon's data.
local _, ns = ...
local Evidence = {}
ns.Evidence = Evidence

local MAX_PATTERN = 200
Evidence.TAIL = 12 -- lines of a log kept as the position where an attempt opened

local function walk(root, path)
    local v = root
    for part in tostring(path or ""):gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part] ~= nil and v[part] or v[tonumber(part) or part]
    end
    return v
end
Evidence.walk = walk

-- A log source is { global = "KeepThatDB", path = "global.log", format = "strings"|"entries" }.
-- Returns an array of message strings, or nil when the log cannot be read.
function Evidence.ReadLog(src, env)
    env = env or _G
    local root = env[src.global]
    if type(root) ~= "table" then return nil end
    local list = walk(root, src.path)
    if type(list) ~= "table" then return nil end
    local out = {}
    for i, e in ipairs(list) do
        if src.format == "entries" then out[i] = type(e) == "table" and tostring(e.msg) or tostring(e)
        else out[i] = tostring(e) end
    end
    return out
end

-- Lines added after the snapshot. Logs repeat the same startup block each session, so find the boundary by
-- position: if the snapshot tail sits exactly at the snapshot length, nothing rolled and the boundary is there.
-- Otherwise (ring rolled) take the last match. Several matches (a repeated run leaves the same lines) make the
-- boundary inexact: a line may be missed, so an absence cannot be shown. Returns array, or nil when the
-- boundary cannot be located (treat as unverified).
-- cap is how many lines the log keeps, when the plan says (a bounded list that drops the oldest line at the cap).
function Evidence.NewLines(snapshot, current, cap)
    if not current then return nil end
    if snapshot and snapshot.unavailable then return nil end -- the log could not be read when the step opened
    if not snapshot then return current, true end
    -- A position is { n = length, tail = last lines }; runs saved before it hold the whole log as an array.
    local n = snapshot.tail and snapshot.n or #snapshot
    local tail = snapshot.tail or snapshot
    if not n or n == 0 then return current, true end
    local k = math.min(Evidence.TAIL, n) -- a long tail: startup blocks repeat every session, so a short one is ambiguous
    local tl = #tail
    local function tailAt(last)
        if last < k or last > #current or tl < k then return false end
        for j = 1, k do if current[last - k + j] ~= tail[tl - k + j] then return false end end
        return true
    end
    local last, found = nil, 0
    if tailAt(n) then last = n
    else
        for i = k, #current do
            if tailAt(i) then found = found + 1; last = i end
        end
        if found == 0 then return nil end
    end
    -- A full ring rolls with every new line, so a boundary found by search is normal. It holds when the tail is
    -- distinctive. A tail made of one repeated line (a flood) can also match lines written after the step opened,
    -- and then a line between could be missed: an absence cannot be shown.
    local seen, distinct = {}, 0
    for j = 1, k do
        local l = tail[tl - k + j]
        if not seen[l] then seen[l] = true; distinct = distinct + 1 end
    end
    local exact = found <= 1 and distinct >= math.ceil(k / 2)
    -- A log that keeps cap lines and holds fewer has never dropped one, so a boundary at the snapshot position is
    -- certain, however alike the lines are.
    if not exact and cap and last == n and #current < cap then exact = true end
    -- A full ring that again reads the saved tail may have rolled all the way: new lines pushed the old ones out and the
    -- last of them repeat the tail. "Nothing new" is then not certain.
    if cap and last == n and #current >= cap then exact = false end
    local out = {}
    for i = last + 1, #current do out[#out + 1] = current[i] end
    return out, exact
end

-- An attempt that has positions but none for this source cannot say which lines are new.
local function missingPosition(a, snapshots)
    return a.scope ~= "session" and snapshots ~= nil and snapshots[a.source] == nil
end

local function lineMatches(a, line)
    if a.equals then return line == a.equals end
    if a.contains then return line:find(a.contains, 1, true) ~= nil end
    if a.pattern then
        if #a.pattern > MAX_PATTERN then return false end
        local ok, r = pcall(string.find, line, a.pattern)
        return ok and r ~= nil
    end
    return false
end

-- The new lines of a source for an assertion: scope session reads the whole log. Returns lines and whether the
-- boundary is exact, or nil and the reason the log cannot be judged.
local function window(a, snapshots, plan, env)
    local src = plan.logs and plan.logs[a.source]
    if not src then return nil, "unknown log source" end
    local current = Evidence.ReadLog(src, env)
    if not current then return nil, "log not readable (is debug on and the addon loaded?)" end
    if a.scope == "session" then return current, true, src end
    if missingPosition(a, snapshots) then return nil, "log position missing (the step opened without it)" end
    if snapshots and snapshots[a.source] and snapshots[a.source].unavailable then return nil, "log was not readable when the step opened" end
    local lines, exact = Evidence.NewLines(snapshots and snapshots[a.source], current, src.cap)
    if not lines then return nil, "log rolled over; evidence lost" end
    return lines, exact, src
end

-- How many matched against a count. Too many fails. Too few is unverified, as the line can still arrive. A count
-- that allows none follows the rules of an absence check: the log must be readable with a known boundary, and
-- a log that is not quiet must show some new line, or it may simply be off.
local function judgeCount(n, c, lines, exact, src, a)
    local lo = c.exactly or c.min or 0
    local hi = c.exactly or c.max or math.huge
    if n > hi then return "fail", ("%d matched, at most %d allowed"):format(n, hi) end
    if n < lo then return "unverified", ("%d matched, %d needed"):format(n, lo) end
    -- A boundary that is not exact may have hidden lines. An upper bound cannot be shown then.
    if hi ~= math.huge and a.scope ~= "session" and exact == false then return "unverified", "log rolled over; a count cannot be shown" end
    if n == 0 then
        if a.scope ~= "session" and exact == false then return "unverified", "log rolled over; a line that is absent cannot be shown" end
        if #lines == 0 and not (src and src.quiet) then return "unverified", "no new log lines (is debug on?)" end
    end
    return "pass"
end

-- What a check looked at, kept with a failed or unverified outcome so a reviewer (or any tool) can name the lines that
-- decided it. Built from the same lines the check judged. Positions n count from 1 inside that window: the lines
-- after the step opened, or the whole retained log for scope session. All values are cut and plain.
Evidence.HITS, Evidence.HIT_LEN, Evidence.RULE_LEN, Evidence.VALUE_LEN = 3, 200, 120, 80

local function cut(s, n)
    s = tostring(s):gsub("%c", " ")
    return #s > n and s:sub(1, n) or s
end

local function valText(v)
    if type(v) == "table" then
        local t = {}
        for i = 1, math.min(#v, 4) do t[i] = tostring(v[i]) end
        return "{" .. table.concat(t, ",") .. "}"
    end
    return tostring(v)
end

-- lit false leaves the plan's literals out ("…"): the shape of a rule is safe to hand to a tool that may not show log text.
local function matcherText(a, lit)
    local function q(s) return lit and cut(s, 60) or "…" end
    if a.equals ~= nil then return ('equals "%s"'):format(q(a.equals)) end
    if a.contains ~= nil then return ('contains "%s"'):format(q(a.contains)) end
    if a.pattern ~= nil then return ('pattern "%s"'):format(q(a.pattern)) end
    return "a line"
end

local function countText(c)
    if c.exactly ~= nil then return "exactly " .. tostring(c.exactly) end
    if c.min ~= nil and c.max ~= nil then return tostring(c.min) .. " to " .. tostring(c.max) end
    if c.min ~= nil then return "at least " .. tostring(c.min) end
    if c.max ~= nil then return "at most " .. tostring(c.max) end
    return "any number"
end

local function ruleOf(a, lit)
    local r
    if a.kind == "log" then
        local m = matcherText(a, lit)
        if a.count then r = "count " .. countText(a.count) .. ": " .. m
        elseif a.absent then r = "absent: " .. m
        else r = "present: " .. m end
    elseif a.kind == "log-sequence" then
        r = ("sequence of %d lines"):format(#(a.sequence or {}))
    elseif a.kind == "fact" then
        r = ("fact [%s] %s %s %s"):format(cut(a.addon, 30), cut(a.key, 40), tostring(a.op), lit and cut(valText(a.value), 40) or "…")
        if a.count then r = r .. ", count " .. countText(a.count) elseif a.which then r = r .. ", " .. tostring(a.which) end
    else
        r = ("%s %s %s %s"):format(tostring(a.probe), cut(a.name or "", 40), tostring(a.op), lit and cut(valText(a.value), 40) or "…")
    end
    return cut(r, Evidence.RULE_LEN)
end

local function baseDetail(a)
    return { kind = a.kind, scope = (a.kind == "log" or a.kind == "log-sequence" or a.kind == "fact") and (a.scope == "session" and "session" or "attempt") or nil,
             source = a.source, label = a.label, rule = ruleOf(a, true), shape = ruleOf(a, false) }
end

-- The first HITS entries of positions pos (a list of window positions), starting at pos[from].
local function takeHits(lines, pos, from, extra)
    local hits = {}
    for k = from, math.min(#pos, from + Evidence.HITS - 1) do
        local i = pos[k]
        local h = { n = i, line = cut(lines[i], Evidence.HIT_LEN) }
        if extra then extra(h, k) end
        hits[#hits + 1] = h
    end
    return #hits > 0 and hits or nil
end

-- A count that went over its upper bound keeps the first line past the bound, then those after it.
local function overflowFrom(c, n, result)
    local hi = c and (c.exactly or c.max)
    if result == "fail" and hi and hi < n then return hi + 1 end
    return 1
end

local function describeLog(a, lines, result)
    local d = baseDetail(a)
    if not lines then return d end
    local pos = {}
    for i, l in ipairs(lines) do if lineMatches(a, l) then pos[#pos + 1] = i end end
    d.window, d.matched = #lines, #pos
    d.hits = takeHits(lines, pos, overflowFrom(a.count, #pos, result))
    return d
end

-- Result: "pass" | "fail" | "unverified", the reason, and (when wantDetail) what the check looked at.
local function judgeLog(a, lines, exact, src)
    if a.count then
        local n = 0
        for _, l in ipairs(lines) do if lineMatches(a, l) then n = n + 1 end end
        return judgeCount(n, a.count, lines, exact, src, a)
    end
    if a.absent and a.scope ~= "session" and exact == false then
        for _, l in ipairs(lines) do if lineMatches(a, l) then return "fail", "a forbidden line appeared" end end
        return "unverified", "log rolled over; a line that is absent cannot be shown"
    end
    local found
    for _, l in ipairs(lines) do if lineMatches(a, l) then found = true; break end end
    if a.absent then
        if found then return "fail", "a forbidden line appeared" end
        if #lines == 0 and not src.quiet then return "unverified", "no new log lines (is debug on?)" end
        return "pass"
    end
    if found then return "pass" end
    return "unverified", "no matching log line"
end

function Evidence.CheckLog(a, snapshots, plan, env, wantDetail)
    local lines, exact, src = window(a, snapshots, plan, env)
    if not lines then return "unverified", exact, wantDetail and describeLog(a, nil) or nil end
    local r, why = judgeLog(a, lines, exact, src)
    return r, why, wantDetail and r ~= "pass" and describeLog(a, lines, r) or nil -- a pass keeps none: no second scan -- a pass keeps none: no second scan
end

-- A fact is stored as the line "[addon] key=value". The value reads as a boolean, a number, or else text.
function Evidence.ParseValue(text)
    if text == "true" then return true elseif text == "false" then return false end
    if text:match("^%-?%d+%.?%d*$") or text:match("^%-?%.%d+$") or text:match("^%-?%d*%.?%d+[eE][%+%-]?%d+$") then
        local n = tonumber(text)
        if n then return n end
    end
    return text
end

function Evidence.ParseFact(line)
    local addon, key, text = tostring(line):match("^%[([^%]]*)%] ([^=]+)=(.*)$")
    if not addon then return nil end
    return addon, key, Evidence.ParseValue(text)
end

-- Operators over a value x (from a probe or a fact), the plan's value v and the assertion a.
local function isnum(x) return type(x) == "number" end
local ops = {
    eq = function(x, v) return x == v end,
    ne = function(x, v) return x ~= v end,
    gt = function(x, v) return isnum(x) and isnum(v) and x > v end,
    ge = function(x, v) return isnum(x) and isnum(v) and x >= v end,
    lt = function(x, v) return isnum(x) and isnum(v) and x < v end,
    le = function(x, v) return isnum(x) and isnum(v) and x <= v end,
    contains = function(x, v) return type(x) == "string" and type(v) == "string" and x:find(v, 1, true) ~= nil end,
    exists = function(x) return x ~= nil end,
    missing = function(x) return x == nil end,
    between = function(x, v) return isnum(x) and type(v) == "table" and isnum(v[1]) and isnum(v[2]) and x >= v[1] and x <= v[2] end,
    approx = function(x, v, a) return isnum(x) and isnum(v) and isnum(a.tolerance) and math.abs(x - v) <= a.tolerance end,
    matches = function(x, v)
        if type(x) ~= "string" or type(v) ~= "string" or #v > MAX_PATTERN then return false end
        local ok, r = pcall(string.find, x, v)
        return ok and r ~= nil
    end,
    type = function(x, v) return type(x) == v end,
    ["in"] = function(x, v)
        if type(v) ~= "table" then return false end
        for _, e in ipairs(v) do if e == x then return true end end
        return false
    end,
}
Evidence.Ops = ops

-- Closed registry of read-only probes. env supplies the game (or a fake).
function Evidence.Probe(a, env)
    env = env or _G
    if a.probe == "addon-loaded" then
        local f = env.IsAddOnLoaded or (env.C_AddOns and env.C_AddOns.IsAddOnLoaded)
        if not f then return nil end
        local r = f(a.name)
        if r == nil then return nil end
        return r and true or false
    elseif a.probe == "global-value" then
        local root = env[a.name]
        if a.path == nil then return root end
        if type(root) ~= "table" then return nil end
        return walk(root, a.path) -- a stored false stays false
    elseif a.probe == "frame-shown" then
        local ok, shown = pcall(function()
            local f = env[a.name]
            if type(f) ~= "table" or type(f.IsShown) ~= "function" then return nil end
            return f:IsShown() and true or false
        end)
        if not ok then return nil end
        return shown
    end
end

-- Ordered matches: each item must appear after the previous one in the attempt window.
function Evidence.CheckSequence(a, snapshots, plan, env, wantDetail)
    local function bad(why, lines) return "unverified", why, wantDetail and (function() local d = baseDetail(a); if lines then d.window = #lines end; return d end)() or nil end
    local src = plan.logs and plan.logs[a.source]
    if not src then return bad("unknown log source") end
    local current = Evidence.ReadLog(src, env)
    if not current then return bad("log not readable (is debug on and the addon loaded?)") end
    if missingPosition(a, snapshots) then return bad("log position missing (the step opened without it)") end
    if a.scope ~= "session" and snapshots and snapshots[a.source] and snapshots[a.source].unavailable then
        return bad("log was not readable when the step opened")
    end
    local lines = a.scope == "session" and current or Evidence.NewLines(snapshots and snapshots[a.source], current, src.cap)
    if not lines then return bad("log rolled over; evidence lost") end
    local want, lastAt = 1, nil
    for i, l in ipairs(lines) do
        if want <= #a.sequence and lineMatches(a.sequence[want], l) then want = want + 1; lastAt = i end
    end
    local done = want > #a.sequence
    local d
    if wantDetail and not done then
        d = baseDetail(a)
        d.window, d.matched = #lines, want - 1
        if lastAt then d.hits = { { item = want - 1, n = lastAt, line = cut(lines[lastAt], Evidence.HIT_LEN) } } end
        if not done then d.stoppedAt = want end
    end
    if done then return "pass", nil, d end
    return "unverified", ("sequence stopped at item %d"):format(want), d
end

-- A fact assertion. No fact is unverified, facts that break the operator fail. With count, the facts that pass
-- the operator are counted. The operator missing passes when no fact arrived.
local function describeFact(a, lines, cands, op, result)
    local d = baseDetail(a)
    d.window = #lines
    local okpos, badpos = {}, {}
    for k, c in ipairs(cands) do if op(c.v, a.value, a) then okpos[#okpos + 1] = k else badpos[#badpos + 1] = k end end
    d.matched = #okpos
    local function pick(ks, from)
        local pos = {}
        for _, k in ipairs(ks) do pos[#pos + 1] = cands[k].n end
        return takeHits(lines, pos, from or 1, function(h, j) h.value = cut(valText(cands[ks[j]].v), Evidence.VALUE_LEN) end)
    end
    local all = {}
    for k = 1, #cands do all[k] = k end
    if a.count then
        d.hits = pick(okpos, overflowFrom(a.count, #okpos, result))
    elseif a.op == "missing" then
        d.matched = #cands
        d.hits = pick(all)
    elseif #cands > 0 then
        local which = a.which or "last"
        if which == "last" then d.hits = pick({ #cands })
        elseif which == "any" then d.hits = pick(badpos, math.max(1, #badpos - Evidence.HITS + 1))   -- the last rejected facts
        elseif result ~= "pass" then d.hits = pick(badpos)   -- all: facts that broke the operator
        end
    end
    return d
end

function Evidence.CheckFact(a, snapshots, plan, env, wantDetail)
    local op = ops[a.op]
    if not op then return "unverified", "unknown op", wantDetail and baseDetail(a) or nil end
    local lines, exact, src = window(a, snapshots, plan, env)
    if not lines then return "unverified", exact, wantDetail and baseDetail(a) or nil end
    local values, cands = {}, {}
    for i, l in ipairs(lines) do
        local addon, key, v = Evidence.ParseFact(l)
        if addon == a.addon and key == a.key then values[#values + 1] = v; cands[#cands + 1] = { n = i, v = v } end
    end
    local r, why
    if a.count then
        local n = 0
        for _, v in ipairs(values) do if op(v, a.value, a) then n = n + 1 end end
        r, why = judgeCount(n, a.count, lines, exact, src, a)
    elseif a.op == "missing" then
        if #values > 0 then r, why = "fail", "the fact arrived"
        else r, why = judgeCount(0, { exactly = 0 }, lines, exact, src, a) end
    elseif #values == 0 then
        r, why = "unverified", "no matching fact"
    else
        local which = a.which or "last"
        if which == "last" then
            if op(values[#values], a.value, a) then r = "pass" else r, why = "fail", "the last fact did not match" end
        else
            local any, all = false, true
            for _, v in ipairs(values) do
                if op(v, a.value, a) then any = true else all = false end
            end
            if which == "any" then
                if any then r = "pass"
                elseif a.scope ~= "session" and exact == false then r, why = "unverified", "log rolled over; a fact that could match may be lost"
                else r, why = "fail", "no fact matched" end
            elseif all and a.scope ~= "session" and exact == false then
                r, why = "unverified", "log rolled over; a fact that could contradict may be lost"
            elseif all then r = "pass"
            else r, why = "fail", "a fact did not match" end
        end
    end
    return r, why, wantDetail and r ~= "pass" and describeFact(a, lines, cands, op, r) or nil
end

function Evidence.CheckState(a, env, wantDetail)
    local d = wantDetail and baseDetail(a) or nil -- cheap: no log scan; dropped by the caller for a pass
    if not ns.Plan.PROBES[a.probe] then return "unverified", "unknown probe", d end
    local op = ops[a.op]
    if not op then return "unverified", "unknown op", d end
    local x = Evidence.Probe(a, env)
    if d and x ~= nil then d.observed = type(x) == "table" and "table" or cut(tostring(x), Evidence.VALUE_LEN) end
    if a.op == "missing" then -- a path that is not there, in a global that is
        local root = a.probe == "global-value" and a.path and (env or _G)[a.name]
        if type(root) ~= "table" then return "unverified", "value unavailable", d end
    elseif x == nil and a.op ~= "exists" then return "unverified", "value unavailable", d end
    return op(x, a.value, a) and "pass" or "fail", nil, d
end

-- Result, reason and, with wantDetail, the record of what the check looked at (see describeLog).
function Evidence.Check(a, snapshots, plan, env, wantDetail)
    if a.kind == "log" then return Evidence.CheckLog(a, snapshots, plan, env, wantDetail) end
    if a.kind == "log-sequence" then return Evidence.CheckSequence(a, snapshots, plan, env, wantDetail) end
    if a.kind == "fact" then return Evidence.CheckFact(a, snapshots, plan, env, wantDetail) end
    return Evidence.CheckState(a, env, wantDetail)
end

-- Live view of the required checks of a step, without recording anything. Each item:
-- { label, state } where state is "met", "waiting", "bad" or "later" (an absence check is judged when the verdict is recorded).
function Evidence.Preview(step, snapshots, plan, env)
    local items = {}
    for _, a in ipairs(step.assertions or {}) do
        if not a.diagnostic then
            local item = { assertion = a, label = a.label }
            local upper = type(a.count) == "table" and (a.count.exactly ~= nil or a.count.max ~= nil)
            if a.absent or upper or (a.kind == "fact" and a.op == "missing") then
                -- Judged at the verdict, but a line that already broke it cannot be taken back: show that at once.
                item.state = Evidence.Check(a, snapshots, plan, env) == "fail" and "bad" or "later"
                item.timed = true -- an automatic step judges it when its timeout ends
            else
                local r = Evidence.Check(a, snapshots, plan, env)
                item.state = (r == "pass" and "met") or (r == "fail" and "bad") or "waiting"
            end
            items[#items + 1] = item
        end
    end
    return items
end

Evidence.EXCERPT, Evidence.EXCERPT_LEN = 20, 200 -- lines kept for each source of a failed attempt, and their length

-- The first new lines of each log the step checks, for the saved record of a failed or unverified attempt:
-- { [source] = { line, ... } }, or nil when there are none. Lines are cut. A log that cannot be read or whose
-- boundary is lost adds nothing. Reads only.
function Evidence.Excerpt(step, snapshots, plan, env)
    local out, any = {}, false
    for _, a in ipairs(step and step.assertions or {}) do
        local name = a.source
        local src = name and plan.logs and plan.logs[name]
        if src and not out[name] and snapshots and snapshots[name] and (a.kind == "log" or a.kind == "log-sequence" or a.kind == "fact") and a.scope ~= "session" then
            local current = Evidence.ReadLog(src, env)
            local lines = current and Evidence.NewLines(snapshots and snapshots[name], current, src.cap)
            if lines and #lines > 0 then
                local kept = {}
                for i = 1, math.min(#lines, Evidence.EXCERPT) do kept[i] = lines[i]:sub(1, Evidence.EXCERPT_LEN) end
                out[name], any = kept, true
            end
        end
    end
    return any and out or nil
end

-- Where the logs a step checks stand when its attempt opens: { [source] = { n, tail } }. Only logs that an
-- attempt-scoped assertion of the step names are recorded. An unreadable log is not an empty one: marking it
-- keeps old lines from counting as new later.
function Evidence.Snapshot(plan, env, step)
    local snaps = {}
    for _, a in ipairs(step and step.assertions or {}) do
        local name = a.source
        if (a.kind == "log" or a.kind == "log-sequence" or a.kind == "fact") and a.scope ~= "session" and name and not snaps[name] then
            local src = plan.logs and plan.logs[name]
            local lines = src and Evidence.ReadLog(src, env)
            if lines then
                local tail = {}
                for i = math.max(1, #lines - Evidence.TAIL + 1), #lines do tail[#tail + 1] = lines[i] end
                snaps[name] = { n = #lines, tail = tail }
            else
                snaps[name] = { unavailable = true }
            end
        end
    end
    return snaps
end

