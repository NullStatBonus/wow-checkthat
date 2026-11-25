-- The client census: the names the running game provides, for the author tools (ct.py census). Plain Lua: every
-- game read comes from the env (Adapter.Env). The walk runs in short steps, a time budget for each frame, and
-- pauses in combat. It reads the game in steps of one read. It stores CheckThatDB.global.census (the newest census of this client) only when the walk is complete.
local _, ns = ...

local Census = {}
ns.Census = Census

Census.BUDGET_MS = 8     -- time for one frame when the client has a clock
Census.BUDGET_READS = 250 -- reads of the game for one frame when it has not
Census.MEMBER_CAP = 2000 -- members read from one table; a larger table is cut and reported

local db, env, state

local function log(msg)
    if ns.Log then ns.Log.Record("census", msg) end
end

function Census.Init(global, e)
    db, env, state = global, e, nil
    -- An older build kept one census for each build; keep only the newest one now.
    if type(db.census) == "table" and db.census.globals == nil then db.census = nil end
end

function Census.Running() return state ~= nil end

-- "1.15.9" and "70576" make the build "1.15.9.70576"; the key is "unknown" when the client cannot say.
local function buildKey()
    local version, build, _, toc = env.GetBuildInfo()
    if type(version) == "string" and build ~= nil then return version .. "." .. tostring(build), toc end
    return "unknown", toc
end

-- A table worth listing: an API namespace (C_*, Enum) or a named public table (MenuUtil). All start with a capital.
local function wanted(name) return name:find("^%u") ~= nil end

local function identifier(k) return type(k) == "string" and k:find("^[%a_][%w_]*$") ~= nil end

-- A timer belongs to the walk that made it: when that walk has ended (or another one began), it does nothing.
-- Returns false when the client cannot schedule (no timers): the caller then works in one pass.
local function schedule(sec)
    local mine = state
    if mine.scheduled then return true end
    mine.scheduled = true
    local ok = env.After and env.After(sec, function()
        if state ~= mine then return end
        mine.scheduled = false
        Census.Tick()
    end)
    if not ok then mine.scheduled = false; return false end
    return true
end

-- The walk cannot go on (the game's names changed under it): keep the stored census, say so, and stop being busy.
local function abort(reason)
    local f = state.onFail
    state = nil
    log("failed " .. reason)
    if f then f() end
    return true
end

local function finish()
    local s = state
    local nTables, nWidgets = 0, 0
    for _ in pairs(s.tables) do nTables = nTables + 1 end
    for _ in pairs(s.widgets) do nWidgets = nWidgets + 1 end
    db.census = { build = s.build, interface = s.toc, date = s.date, addons = env.LoadedAddons and env.LoadedAddons() or nil,
        globals = s.globals, insecure = s.insecure, tables = s.tables, widgets = s.widgets, unavailable = s.unavailable,
        truncated = #s.truncated > 0 and s.truncated or nil, unfiltered = s.unfiltered or nil }
    state = nil
    log(("done %s %d globals %d tables %d widget types %d addon%s"):format(s.build, s.nGlobals, nTables, nWidgets, s.nAddon,
        s.unfiltered and " unfiltered" or ""))
    if s.onDone then s.onDone() end
end

local function closeTable(cur)
    local s = state
    if cur.filtered ~= true or cur.unknown then s.unfiltered = true end
    if cur.truncated then s.truncated[#s.truncated + 1] = cur.name end
    if cur.any then s.tables[cur.name] = cur.out end
    s.cur = nil
end

-- One small unit of work: one read of the game. Returns false when the walk is complete.
local function step()
    local s = state
    if s.phase == "keys" then
        local ok, k = env.CensusNextKey(s.cursor)
        if not ok then return abort("names unreadable") end
        if k == nil then s.i, s.phase = 0, "types"; return true end
        s.cursor = k
        if type(k) == "string" then s.names[#s.names + 1] = k end
    elseif s.phase == "types" then
        s.i = s.i + 1
        local name = s.names[s.i]
        if not name then
            s.i, s.phase = 0, "scan"
        else
            local t, secure = env.CensusType(name)
            if t and secure == false then
                s.nAddon = s.nAddon + 1 -- last written by addon code: kept apart, members not walked
                s.insecure[name] = t
            elseif t then
                if secure == nil then s.unfiltered = true end -- the client cannot tell the game's names from an addon's
                s.globals[name] = t; s.nGlobals = s.nGlobals + 1
            end
        end
    elseif s.phase == "scan" then
        s.i = s.i + 1
        local n = s.names[s.i]
        if not n then s.i, s.phase = 0, "tables"
        elseif s.globals[n] == "table" and wanted(n) then s.candidates[#s.candidates + 1] = n end
    elseif s.phase == "tables" then
        local cur = s.cur
        if not cur then
            s.i = s.i + 1
            local name = s.candidates[s.i]
            if not name then s.i, s.phase = 0, "widgets"; return true end
            local h, isFrame, filtered = env.CensusOpen(name)
            if h and not isFrame then s.cur = { name = name, h = h, filtered = filtered, out = {}, n = 0 } end
        else
            local ok, k, t, keep, unknown = env.CensusMember(cur.h, cur.cursor)
            if not ok then s.cur = nil -- the table changed under the walk: it is left out
            elseif k == nil then closeTable(cur)
            elseif cur.n >= Census.MEMBER_CAP then cur.truncated = true; closeTable(cur)
            else
                cur.n, cur.cursor = cur.n + 1, k
                if unknown then cur.unknown = true end -- an answer is missing for a real key: this table is unfiltered
                if keep and identifier(k) and type(t) == "string" then cur.out[k] = t; cur.any = true end
            end
        end
    elseif s.phase == "widgets" then
        s.i = s.i + 1
        local kind = s.kinds[s.i]
        if not kind then return false end
        local methods = env.CensusWidget(kind)
        if methods then
            local list = {}
            for _, m in ipairs(methods) do if identifier(m) then list[#list + 1] = m end end
            s.widgets[kind] = list
        else
            s.unavailable[#s.unavailable + 1] = kind
        end
    end
    return true
end

-- Runs steps until the frame budget is spent, then asks for the next frame. Waits while in combat.
-- When the client cannot schedule, it works in one pass and stops at combat; the next /ct census starts over.
function Census.Tick()
    if not state then return end
    if env.InCombatLockdown() then
        if not state.paused then state.paused = true; log("paused for combat") end
        if not schedule(1) then state = nil; log("stopped for combat: no timers") end
        return
    end
    if state.paused then state.paused = false; log("resumed") end
    local t0, n = env.Clock and env.Clock(), 0
    while true do
        if not step() then return finish() end
        if not state then return end -- aborted
        if state.sync then
            if env.InCombatLockdown() then state = nil; return end
        else
            n = n + 1
            local spent
            if t0 then spent = env.Clock() - t0 >= Census.BUDGET_MS else spent = n >= Census.BUDGET_READS end
            if spent then
                if schedule(0) then return end
                state.sync = true
            end
        end
    end
end

-- The player left combat: carry on at once instead of waiting for the next tick.
function Census.Resume()
    if state and state.paused then Census.Tick() end
end

-- Returns "started", "busy" or "combat". onDone() runs when the walk completes; onFail() when it cannot go on.
function Census.Start(onDone, onFail)
    if state then return "busy" end
    if env.InCombatLockdown() then return "combat" end
    local build, toc = buildKey()
    state = { phase = "keys", build = build, toc = toc, date = env.date and env.date("%Y-%m-%d") or nil, onDone = onDone, onFail = onFail, names = {}, candidates = {},
        globals = {}, insecure = {}, tables = {}, widgets = {}, unavailable = {}, truncated = {}, nGlobals = 0, nAddon = 0,
        kinds = env.CensusWidgetKinds() or {} } -- a type CreateFrame refuses goes to "unavailable"
    log("started " .. build)
    if not schedule(0) then state.sync = true; Census.Tick() end
    return "started"
end
