-- Read-only evidence: addon debug logs and state probes. Never writes to another addon's data.
local _, ns = ...
local Evidence = {}
ns.Evidence = Evidence

local MAX_PATTERN = 200

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
-- Otherwise (ring rolled) accept a single match; several matches are ambiguous. Returns array, or nil when the
-- boundary cannot be located (treat as unverified).
function Evidence.NewLines(snapshot, current)
    if not current then return nil end
    if snapshot and snapshot.unavailable then return nil end -- the log could not be read when the step opened
    if not snapshot or #snapshot == 0 then return current end
    local n = #snapshot
    local k = math.min(12, n) -- a long tail: startup blocks repeat every session, so a short one is ambiguous
    local function tailAt(last)
        if last < k or last > #current then return false end
        for j = 1, k do if current[last - k + j] ~= snapshot[n - k + j] then return false end end
        return true
    end
    local last
    if tailAt(n) then last = n
    else
        local found = 0
        for i = k, #current do
            if tailAt(i) then found = found + 1; last = i end
        end
        if found ~= 1 then return nil end
    end
    local out = {}
    for i = last + 1, #current do out[#out + 1] = current[i] end
    return out
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

-- Result: "pass" | "fail" | "unverified"
function Evidence.CheckLog(a, snapshots, plan, env)
    local src = plan.logs and plan.logs[a.source]
    if not src then return "unverified", "unknown log source" end
    local current = Evidence.ReadLog(src, env)
    if not current then return "unverified", "log not readable (is debug on and the addon loaded?)" end
    local lines = current
    if a.scope ~= "session" then
        if snapshots and snapshots[a.source] and snapshots[a.source].unavailable then return "unverified", "log was not readable when the step opened" end
        lines = Evidence.NewLines(snapshots and snapshots[a.source], current)
        if not lines then return "unverified", "log rolled over; evidence lost" end
    end
    local found
    for _, l in ipairs(lines) do if lineMatches(a, l) then found = true; break end end
    if a.absent then
        if found then return "fail" end
        if #lines == 0 then return "unverified", "no new log lines (is debug on?)" end
        return "pass"
    end
    if found then return "pass" end
    return "unverified", "no matching log line"
end

local ops = {
    eq = function(x, v) return x == v end,
    ne = function(x, v) return x ~= v end,
    gt = function(x, v) return type(x) == "number" and type(v) == "number" and x > v end,
    lt = function(x, v) return type(x) == "number" and type(v) == "number" and x < v end,
    contains = function(x, v) return type(x) == "string" and type(v) == "string" and x:find(v, 1, true) ~= nil end,
    exists = function(x) return x ~= nil end,
}

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
function Evidence.CheckSequence(a, snapshots, plan, env)
    local src = plan.logs and plan.logs[a.source]
    if not src then return "unverified", "unknown log source" end
    local current = Evidence.ReadLog(src, env)
    if not current then return "unverified", "log not readable (is debug on and the addon loaded?)" end
    if a.scope ~= "session" and snapshots and snapshots[a.source] and snapshots[a.source].unavailable then
        return "unverified", "log was not readable when the step opened"
    end
    local lines = a.scope == "session" and current or Evidence.NewLines(snapshots and snapshots[a.source], current)
    if not lines then return "unverified", "log rolled over; evidence lost" end
    local want = 1
    for _, l in ipairs(lines) do
        if want <= #a.sequence and lineMatches(a.sequence[want], l) then want = want + 1 end
    end
    if want > #a.sequence then return "pass" end
    return "unverified", ("sequence stopped at item %d"):format(want)
end

function Evidence.CheckState(a, env)
    if not ns.Plan.PROBES[a.probe] then return "unverified", "unknown probe" end
    local op = ops[a.op]
    if not op then return "unverified", "unknown op" end
    local x = Evidence.Probe(a, env)
    if x == nil and a.op ~= "exists" then return "unverified", "value unavailable" end
    return op(x, a.value) and "pass" or "fail"
end

function Evidence.Check(a, snapshots, plan, env)
    if a.kind == "log" then return Evidence.CheckLog(a, snapshots, plan, env) end
    if a.kind == "log-sequence" then return Evidence.CheckSequence(a, snapshots, plan, env) end
    return Evidence.CheckState(a, env)
end

-- Live view of the required checks of a step, without recording anything. Each item:
-- { label, state } where state is "met", "waiting", "bad" or "later" (an absence check is judged when the verdict is recorded).
function Evidence.Preview(step, snapshots, plan, env)
    local items = {}
    for _, a in ipairs(step.assertions or {}) do
        if not a.diagnostic then
            local item = { assertion = a, label = a.label }
            if a.absent then item.state = "later"
            else
                local r = Evidence.Check(a, snapshots, plan, env)
                item.state = (r == "pass" and "met") or (r == "fail" and "bad") or "waiting"
            end
            items[#items + 1] = item
        end
    end
    return items
end

function Evidence.Snapshot(plan, env)
    local snaps = {}
    -- An unreadable log is not an empty one: marking it keeps old lines from counting as new later.
    for name, src in pairs(plan.logs or {}) do snaps[name] = Evidence.ReadLog(src, env) or { unavailable = true } end
    return snaps
end
