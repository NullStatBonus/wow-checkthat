-- Judges a plan's checks against saved variables, offline.
--
--   luajit tools/replay_sv.lua PLAN.json FIXTURE.lua [FIXTURE.lua ...]     (prints the result as JSON)
--
-- PLAN.json is the plan as ct.py compiles it (cases expanded, sections merged). Each FIXTURE.lua is a SavedVariables file.
-- Every check reads the whole log, as scope session does: the step's own window is not in the fixture. A check that
-- needs that window to pass (absent, exactly, max, a fact that is missing) never passes here: it is "skipped". It can
-- still fail, when the whole log already contradicts it. A state probe needs the game and is "skipped".
local here = arg[0]:match("^(.*)/tools/[^/]*$") or "."
local ns = { Plan = { PROBES = {} } }
assert(loadfile(here .. "/CheckThat/Model/Json.lua"))("CheckThat", ns)
assert(loadfile(here .. "/CheckThat/Model/Evidence.lua"))("CheckThat", ns)
local Evidence = ns.Evidence

local function fail(msg) io.stderr:write(msg, "\n"); os.exit(2) end

local f = io.open(arg[1], "rb") or fail("cannot open " .. tostring(arg[1]))
local plan, err = ns.Json.Decode(f:read("*a")); f:close()
if not plan then fail(err) end

local env = {}
for i = 2, #arg do
    local chunk, e = loadfile(arg[i])
    if not chunk then fail(e) end
    setfenv(chunk, env)
    local ok, e2 = pcall(chunk)
    if not ok then fail(tostring(e2)) end
end

local function needsWindow(a)
    local c = a.count or {}
    return a.absent or c.exactly ~= nil or c.max ~= nil or (a.kind == "fact" and a.op == "missing")
end

local function label(a)
    return a.label or (a.kind .. " " .. tostring(a.equals or a.contains or a.pattern or a.key or a.probe or ""))
end

local function judge(a)
    if a.kind == "state" then return "skipped", "a state probe needs the game" end
    local src = plan.logs and plan.logs[a.source]
    if not (src and Evidence.ReadLog(src, env)) then return "skipped", "the fixture does not hold this log" end
    local b = {}
    for k, v in pairs(a) do b[k] = v end
    b.scope = "session"
    local r, why = Evidence.Check(b, nil, plan, env)
    if r == "pass" then
        if needsWindow(a) then return "skipped", "not judged offline: this check needs the step's own window" end
        return "pass"
    end
    return "fail", why
end

local out = {}
for _, sec in ipairs(plan.sections) do
    for _, st in ipairs(sec.steps) do
        for _, a in ipairs(st.assertions or {}) do
            if not a.diagnostic then
                local r, why = judge(a)
                out[#out + 1] = { step = st.id, label = label(a), result = r, why = why }
            end
        end
    end
end
local s, e = ns.Json.Encode(out)
if not s then fail(e) end
io.write(s, "\n")
