-- Offline runner for addon code. Prototype for issue 94: it reads its own spec file, not a plan.
--
--   luajit tools/entry_runner.lua SPEC.json      (from the repository root; prints the result as JSON)
--
-- SPEC.json: { "toc": "path/Addon.toc", "level": 4,
--              "mocks": { "GetItemInfo": [ {"args": [1], "returns": ["A"]}, {"returns": ["Z"]} ],
--                         "C_Item.GetItemCount": {"returns": [3]} },
--              "mockAfterLoad": false,
--              "steps": [ {"call": {"addon": "A", "entry": "add", "args": [1, 2]}, "returns": [3]},
--                         {"call": {"addon": "A", "entry": "boom"}, "throws": "bad input"},
--                         {"event": {"name": "MERCHANT_SHOW", "args": []}},
--                         {"mockCalls": {"api": "GetItemInfo", "count": 2}},
--                         {"reload": true} ] }
-- Level 3 also takes "savedVariables": {"AddonDB": {...}}, and "groups": [{"label", "mocks", "savedVariables", "steps"}]
-- in place of "steps": each group gets a fresh load. Level 4 adds {"wait": seconds} steps.
-- Everything in a spec is data. A step can only call an entry the addon registered through CheckThat.Entry.
-- Mocks are set before the addon loads (a file-scope "local f = f" then sees them) unless mockAfterLoad is set,
-- and the earlier values come back when the run ends. Every step result says whether mocks were in play.
local Runner = {}
-- CheckThat.Commands' checks (App.DeclareCommands in CheckThat/Model/App.lua, which needs the whole addon), on CheckThat's own Plan
-- rules. tests/test_app.lua checks that both give the same answers.
function Runner.declareCommands(Plan, addon, list)
    if type(addon) ~= "string" or #addon > Plan.ADDON_MAX or not addon:match(Plan.ADDON_NAME) then return false end
    if type(list) ~= "table" or #list == 0 or #list > Plan.COMMANDS_MAX then return false end
    for _, c in ipairs(list) do if Plan.CommandProblem(c, addon) then return false end end
    return true
end
local loadfile = loadfile -- read now: the fake client hides it from addon code, and CheckThat's modules load during a load

-- The newest offline level. A plan without a level runs at level 1, so its results do not change.
Runner.LEVEL = 6

-- The APIs a spec may mock. The runner owns this list; a spec cannot add to it. A name here needs a test.
Runner.MOCKABLE = {}
for _, n in ipairs({ "GetItemInfo", "GetItemCount", "C_Item.GetItemInfo", "C_Item.GetItemCount", "GetMoney", "GetTime",
    "UnitName", "IsInGuild", "GetNumGroupMembers", "GetContainerNumFreeSlots", "C_Container.GetContainerNumFreeSlots",
    "C_Container.GetContainerItemInfo",
    -- the read-only vendor, trainer and auction window calls CTProbe records (#240); the calls that buy, learn or bid stay off the list
    "GetMerchantNumItems", "GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantItemID", "GetNumTrainerServices", "GetTrainerServiceInfo",
    "GetTrainerServiceCost", "GetTrainerServiceSkillReq", "GetTrainerServiceLevelReq", "IsTradeskillTrainer", "GetTrainerServiceTypeFilter",
    "GetNumAuctionItems", "GetAuctionItemInfo", "GetAuctionItemLink",
    -- Forever's vendor row and auction house results return tables (#234)
    "C_MerchantFrame.GetItemInfo", "C_AuctionHouse.GetBrowseResults", "C_AuctionHouse.HasFullBrowseResults", "C_AuctionHouse.GetNumItemSearchResults",
    "C_AuctionHouse.HasFullItemSearchResults", "C_AuctionHouse.GetItemSearchResultInfo", "C_AuctionHouse.GetItemKeyInfo",
    "C_AuctionHouse.GetNumCommoditySearchResults", "C_AuctionHouse.HasFullCommoditySearchResults", "C_AuctionHouse.GetCommoditySearchResultInfo" }) do Runner.MOCKABLE[n] = true end

-- From level 5 a spec may also mock any function the client's surface lists (#214), except Lua's own (H.luaFunction) and these: the
-- fake client's taint, frame, combat, error and timer model rests on them, so a mock would fake that model rather than a game answer.
-- A name ending in "." covers its whole table.
Runner.UNMOCKABLE = {}
for _, n in ipairs({ "CreateFrame", "hooksecurefunc", "issecurevariable", "issecure", "securecall", "securecallfunction", "secureexecuterange",
    "forceinsecure", "InCombatLockdown", "RunScript", "seterrorhandler", "geterrorhandler", "C_Timer." }) do Runner.UNMOCKABLE[n] = true end

-- Whether a spec may mock api. surface is the level 5 client surface, or nil below level 5 (the closed list only). A name the surface
-- lacks is allowed here: the load step then fails it as a function the client does not have.
function Runner.mockable(api, surface, H)
    if Runner.MOCKABLE[api] then return true end
    if not surface then return false end
    local ns = api:match("^([^%.]+)%.")
    return not (H.luaFunction(api) or Runner.UNMOCKABLE[api] or (ns and Runner.UNMOCKABLE[ns .. "."]))
end

-- An absolute path (/x, C:\x, C:/x or \\server\x) is kept; any other is under root.
local function pathJoin(root, p)
    if p:sub(1, 1) == "/" or p:match("^%a:[/\\]") or p:sub(1, 2) == "\\\\" then return p end
    return root .. "/" .. p
end
Runner.pathJoin = pathJoin

local function deepEq(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not deepEq(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- got is a packed list (n counts trailing nils); want is a decoded array.
local function sameList(got, want)
    if got.n ~= #want then return false end
    for i = 1, got.n do if not deepEq(got[i], want[i]) then return false end end
    return true
end

local function show(list)
    local parts = {}
    for i = 1, list.n or #list do parts[i] = tostring(list[i]) end
    return "[" .. table.concat(parts, ", ") .. "]"
end

local function pack(...) return { n = select("#", ...), ... } end

-- Mocks. A mock replaces one global (or one field of a table global) with a function that answers from rules.
local function walk(path, create)
    local parts = {}
    for p in path:gmatch("[^%.]+") do parts[#parts + 1] = p end
    local t = _G
    for i = 1, #parts - 1 do
        if type(t[parts[i]]) ~= "table" then
            if not create then return nil end
            t[parts[i]] = {}
        end
        t = t[parts[i]]
    end
    return t, parts[#parts]
end

local function copyValue(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copyValue(x) end
    return c
end

local function makeMock(rules, counts, api)
    if rules.returns or rules.args then rules = { rules } end
    return function(...)
        counts[api] = (counts[api] or 0) + 1
        local args = pack(...)
        for _, rule in ipairs(rules) do
            local ok = true
            for i, want in ipairs(rule.args or {}) do
                if not deepEq(args[i], want) then ok = false; break end
            end
            if ok then -- n keeps the nils of a recording; a table return is a fresh copy each call, as the game's is
                local out, want = {}, rule.returns or {}
                for i = 1, rule.n or #want do out[i] = copyValue(want[i]) end
                return unpack(out, 1, rule.n or #want)
            end
        end
    end
end

local function applyMocks(mocks, counts, saved)
    for api, rules in pairs(mocks or {}) do
        local t, key = walk(api, true)
        saved[#saved + 1] = { t = t, key = key, old = t[key] }
        t[key] = makeMock(rules, counts, api)
    end
end

local function restoreMocks(saved)
    for i = #saved, 1, -1 do saved[i].t[saved[i].key] = saved[i].old end
end

-- Loads every file a TOC lists (following its XML files, see H.tocFiles), with the addon's own (name, ns) arguments.
-- The Lua 5.1 scanner (tools/lua51_check.lua) runs over every file first: LuaJIT accepts syntax the game rejects.
local function compileToc(Lua51, H, path)
    local files, err = H.tocFiles(path)
    if not files then return false, err end
    local found = {}
    for _, file in ipairs(files) do
        for _, m in ipairs(Lua51.check(file)) do found[#found + 1] = m end
    end
    if #found > 0 then return false, table.concat(found, "; ") end
    local chunks = {}
    for _, file in ipairs(files) do
        local chunk, lerr = loadfile(file)
        if not chunk then return false, lerr end
        chunks[#chunks + 1] = chunk
    end
    return chunks
end

local function runChunks(chunks, name, ns)
    for _, chunk in ipairs(chunks) do
        local ok, e = pcall(chunk, name, ns)
        if not ok then return false, tostring(e) end
    end
    return true
end

-- What the game gives no addon: file, process and JIT access. Hidden while the addon's code runs; a guard such as
-- "if io then" sees nil and a call fails with Lua's own message.
Runner.HIDDEN = { "io", "os", "jit", "ffi", "require", "package", "loadfile", "dofile" }
local function hideGlobals()
    local saved = {}
    for _, n in ipairs(Runner.HIDDEN) do saved[n] = rawget(_G, n); rawset(_G, n, nil) end
    -- every name goes back, nil included: an addon that assigned one (such as ffi) must not leak it to the host
    return function() for _, n in ipairs(Runner.HIDDEN) do rawset(_G, n, saved[n]) end end
end

local function tocInterface(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a"); f:close()
    for l in (text .. "\n"):gmatch("([^\r\n]*)[\r\n]") do -- the key counts only at the start of a line
        local n = l:match("^%s*##%s*Interface%s*:%s*(%d+)")
        if n then return tonumber(n) end
    end
    return nil
end

-- What the game writes for a saved variable: strings, numbers, booleans and tables with such keys. Functions, userdata
-- and threads are dropped, two references to one table come back as two tables, and a reference to a table the copy is
-- already inside is dropped.
local function savedCopy(v, inside)
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then return v end
    if t ~= "table" then return nil end
    inside = inside or {}
    if inside[v] then return nil end
    inside[v] = true
    local out = {}
    for k, x in next, v do
        local kt = type(k)
        if kt == "string" or kt == "number" or kt == "boolean" then out[k] = savedCopy(x, inside) end
    end
    inside[v] = nil
    return out
end

local function hasReload(steps)
    for _, s in ipairs(steps or {}) do if s.reload then return true end end
    return false
end

-- spec is a decoded table. opts.root is the repository root (default "."); opts.prepare(H, st) runs after the
-- fake client is built, so a test can add the "real" values a mock will replace. opts.loaded(ns, st, n) runs after
-- load n of the addon (1 for the first, then once for each reload or group), so a test can drive the addon's own code.
function Runner.run(spec, opts)
    -- The host's own values of the hidden names, taken before a level 5 surface strips require, dofile and loadfile: a hook gets them all.
    local host = {}
    for _, n in ipairs(Runner.HIDDEN) do host[n] = rawget(_G, n) end
    opts = opts or {}
    local root = opts.root or "."
    local jns = {}
    assert(loadfile(root .. "/CheckThat/Model/Json.lua"))("CheckThat", jns)
    local _, _, _, _, H = dofile(root .. "/tests/harness.lua")()
    local Lua51 = dofile(root .. "/tools/lua51_check.lua")
    local tocPath = pathJoin(root, spec.toc)
    -- The TOC's interface: its first number, or the one ct test names for the client it runs (opts, never a plan's key).
    local function tocIface() return opts.interface or tocInterface(tocPath) end
    -- Offline level: what a plan opted in to. Level 1 (no level) keeps the fake client's first answers: interface 11507
    -- and issecurevariable false for every name. Level 2 answers with the TOC's interface and the secure game names.
    -- Level 3 adds the game's load order: saved variables, login events, reload and groups. Level 4 adds the client's
    -- event list (tools/events/<client>.json) and a virtual clock with wait steps.
    local level = spec.level or 1
    local badLevel = type(level) ~= "number" or level % 1 ~= 0 or level < 1 or level > Runner.LEVEL
    if badLevel then level = 1 end
    local lifecycle = level >= 3
    local timed = level >= 4
    local strict = level >= 5
    local groups = spec.groups or { { steps = spec.steps } }
    local grouped = spec.groups ~= nil
    local needs3
    if spec.groups then needs3 = "groups" elseif spec.savedVariables then needs3 = "savedVariables" end
    for _, g in ipairs(groups) do
        if not needs3 and g.savedVariables then needs3 = "savedVariables" end
        if not needs3 and hasReload(g.steps) then needs3 = "a reload step" end
    end
    local needs4
    for _, g in ipairs(groups) do
        for _, s in ipairs(g.steps or {}) do if s.wait ~= nil then needs4 = "a wait step" end end
    end
    local needs5
    for _, g in ipairs(groups) do
        for _, s in ipairs(g.steps or {}) do if s.tooltip ~= nil then needs5 = "a tooltip step" end end
    end
    if spec.recordings ~= nil then needs5 = needs5 or "recordings" end
    -- Lua hooks (#273's first slice): the developer's own file, named by the block and loaded once before the addon. A hook step calls
    -- hooks[name](ctx, ...). The names are checked here, so a typo fails the load step before any addon file runs.
    local hookNames = {}
    for _, g in ipairs(groups) do
        for _, s in ipairs(g.steps or {}) do if s.hook ~= nil then hookNames[#hookNames + 1] = s.hook end end
    end
    if spec.hooks ~= nil then needs5 = needs5 or "hooks" end
    if #hookNames > 0 then needs5 = needs5 or "a hook step" end
    local hooks
    local function loadHooks() -- after the other load checks pass, so the file runs only for a load that goes ahead; returns an error or nil
        if spec.hooks == nil and #hookNames == 0 then return nil end
        local hooksErr
        if type(opts.hooks) == "table" then -- ct test (tools/addon_test.lua): the test file's functions, never a plan's
            hooks = opts.hooks
            for _, n in ipairs(hookNames) do
                if type(hooks[n]) ~= "function" then return ("hook %s is not in %s"):format(tostring(n), tostring(opts.hooksFile)) end
            end
            return nil
        end
        if type(spec.hooks) ~= "string" then
            hooksErr = "a hook step needs a hooks file (offline.hooks)"
        else
            local chunk, lerr = loadfile(pathJoin(root, spec.hooks))
            local ok, t = false, lerr
            if chunk then ok, t = pcall(chunk) end
            if not chunk then hooksErr = ("hooks %s cannot be loaded: %s"):format(spec.hooks, tostring(lerr))
            elseif not ok then hooksErr = ("hooks %s raised %s"):format(spec.hooks, tostring(t))
            elseif type(t) ~= "table" then hooksErr = ("hooks %s returned %s, not a table of functions"):format(spec.hooks, type(t))
            else
                hooks = t
                for _, n in ipairs(hookNames) do
                    if type(t[n]) ~= "function" then hooksErr = ("hook %s is not in %s"):format(tostring(n), spec.hooks); break end
                end
            end
        end
        return hooksErr
    end
    -- Level 5: the client's real surface (tools/clients/<client>.json): only its game functions, its build, and frames
    -- with only their widget type's methods. A mock of a function the client lacks would hide the gap: it fails the load.
    local surface, surfaceErr
    if strict then
        local n = tocIface() or 11507
        surface, surfaceErr = H.clientSurface(n >= 16000 and "forever" or "era", root)
    end
    -- Level 4: the events of the client the TOC names (below interface 16000 Era, from 16000 Forever), from Blizzard's
    -- generated API documentation and the events Blizzard's own code registers. An event step is checked before load.
    local events, eventsErr
    -- What is wrong with firing name with nargs values on this client (level 4), or nil. who names the step or ctx.fire.
    local function eventProblem(evName, nargs, who)
        local e = events and events[evName]
        if not e then return ("the client has no event %s"):format(tostring(evName)) end
        if e.payload and (nargs > e.payload or nargs < e.required) then
            return ("%s carries %d value(s), %d of them always, and %s gives %d"):format(evName, e.payload, e.required, who, nargs)
        end
    end
    if timed then
        local n = tocIface() or 11507
        local client = n >= 16000 and "forever" or "era"
        local f = io.open(root .. "/tools/events/" .. client .. ".json", "r")
        if f then
            local m = jns.Json.Decode(f:read("*a")); f:close()
            events = m and m.events
        end
        if not events then eventsErr = ("no event list for %s (tools/events/%s.json)"):format(client, client) end
        for _, g in ipairs(groups) do
            for _, s in ipairs(g.steps or {}) do
                local ev = s.event
                if ev and events and not eventsErr then eventsErr = eventProblem(ev.name, #(ev.args or {}), "the step") end
            end
        end
    end
    local meta = lifecycle and H.tocMeta(tocPath) or { savedVariables = {} }
    local declared = {}
    for _, n in ipairs(meta and meta.savedVariables or {}) do declared[n] = true end
    local undeclared
    local function checkDeclared(sv) for n in pairs(sv or {}) do if not undeclared and not declared[n] then undeclared = n end end end
    checkDeclared(spec.savedVariables)
    for _, g in ipairs(groups) do checkDeclared(g.savedVariables) end

    local restoreGlobals = H.snapshot()
    local plainCreate, oldCT -- what the run puts back at the end: the stub client's CreateFrame and CheckThat after prepare
    -- The game passes the folder name; ct test names the addon from its TOC files (opts.addonName), as a checkout's folder may differ.
    local name = opts.addonName or spec.toc:match("([^/\\]+)[/\\][^/\\]+%.toc$") or spec.toc:match("([^/\\]+)%.toc$") or "Addon"
    local folder = tocPath:match("^(.*)[/\\][^/\\]+$") or "."
    -- ADDON_LOADED's second value: whether the addon folder holds Bindings.xml. ADDONS_UNLOADING gets closingClient false.
    local hasBindings, ctBindings = false, false
    do local f = io.open(folder .. "/Bindings.xml"); if f then f:close(); hasBindings = true end end
    do local f = io.open(root .. "/CheckThat/Bindings.xml"); if f then f:close(); ctBindings = true end end -- for ct test's late CheckThat
    local reports, results, nilSeen = {}, {}, {}
    local interface
    local cur = {} -- the current load: st, entries, saved mocks, counts, unhide, stopNil, facts, api, runEvents
    local loads = 0
    -- ct test (opts.checkThat): the run ctx.run opened, in RunEvents' shape. It lives outside the load, so it stays open across a reload.
    local openRun
    local ctModules -- CheckThat's own Plan, Facts, Entries and RunEvents, compiled once
    -- The table the game gives as the global CheckThat (Facts.API), built from CheckThat's own modules for each load, as the game loads
    -- CheckThat again at a reload. Entry also keeps the function for ctx.entry.
    local function realCheckThat()
        if not ctModules then
            ctModules = {}
            for _, m in ipairs({ "Plan", "Facts", "Entries", "RunEvents" }) do
                ctModules[#ctModules + 1] = assert(loadfile(root .. "/CheckThat/Model/" .. m .. ".lua"))
            end
        end
        local cns = {}
        for _, chunk in ipairs(ctModules) do chunk("CheckThat", cns) end
        local Plan = cns.Plan
        -- An OnRun error goes to CheckThat's error list in game; here ctx.run and ctx.reload raise with it.
        cns.Errors = { Record = function(msg) cur.runErrs[#cur.runErrs + 1] = (tostring(msg):gsub("^run callback: ", "")) end }
        cns.App = { DeclareCommands = function(addon, list) return Runner.declareCommands(Plan, addon, list) end }
        cns.Facts.Bind(cur.facts, function() return math.floor(cur.st.now or 0) end, function() return openRun ~= nil end)
        cns.RunEvents.Bind(function() return openRun end)
        cur.runEvents = cns.RunEvents
        local api = cns.Facts.API()
        local store, entries = api.Entry, cur.entries
        api.Entry = function(addon, ename, fn)
            local stored = store(addon, ename, fn)
            if stored then entries[addon] = entries[addon] or {}; entries[addon][ename] = fn end
            return stored
        end
        return api
    end

    local allMocks = {}
    for api in pairs(spec.mocks or {}) do allMocks[api] = true end
    for _, g in ipairs(groups) do for api in pairs(g.mocks or {}) do allMocks[api] = true end end
    local mockNames = {}
    for api in pairs(allMocks) do mockNames[#mockNames + 1] = api end
    table.sort(mockNames)
    local unlisted
    for _, api in ipairs(mockNames) do if not Runner.mockable(api, surface, H) then unlisted = api; break end end
    -- A mock entry { recording = "GetItemInfo(6948)" } takes its args and returns from tools/recordings/<client>.json (made from a CTProbe
    -- run by ct.py recordings) for the client the TOC names. The entry is filled in place: makeMock then reads it like any other.
    local recErr, recFileErr
    local recPaths = {} -- the files a recording label is looked up in, for the error
    local function fill(api, entry)
        if type(entry) ~= "table" or not entry.recording then return end
        local label = entry.recording
        if entry.args ~= nil or entry.returns ~= nil then recErr = recErr or ("mock %s: a recording cannot be combined with args or returns"):format(api); return end
        if not surface then recErr = recErr or ("mock %s: a recording needs offline level 5"):format(api); return end
        local bare = label:gsub("^%l+:", "", 1) -- a scene name ("gear:", recording rev 3) comes before the call
        if bare:sub(1, #api + 1) ~= api .. "(" then recErr = recErr or ("mock %s: the recording %s is for another function"):format(api, label); return end
        local call = surface.recordings and surface.recordings.calls and surface.recordings.calls[label]
        if recFileErr then recErr = recErr or recFileErr; return end
        if not call then
            recErr = recErr or ("mock %s: no recording %s for the %s client (%s)"):format(api, label, surface.client, table.concat(recPaths, " or "))
            return
        end
        local function copy(list) local c = {}; for i, v in pairs(list or {}) do c[i] = v end; return c end -- the recording stays as it was read
        entry.recording, entry.args, entry.returns, entry.n = nil, copy(call.args), copy(call.returns), call.n
        for _, i in ipairs(call.nils or {}) do entry.returns[i] = nil end -- the JSON has no null: a nil return is listed in nils
    end
    local function fillMocks(mocks)
        for api, v in pairs(mocks or {}) do
            if type(v) == "table" then
                fill(api, v)
                for _, entry in ipairs(v) do fill(api, entry) end
            end
        end
    end
    -- The bundled recordings, then the addon's own folder (spec.recordings, #214): for the same label the addon's entry wins.
    -- A folder without the client's file adds nothing.
    if surface then
        local calls = {}
        local function read(path, shown)
            recPaths[#recPaths + 1] = shown
            local rf = io.open(path, "r")
            if not rf then return end
            local rec, derr = jns.Json.Decode(rf:read("*a")); rf:close()
            if type(rec) ~= "table" then recFileErr = recFileErr or ("%s cannot be read: %s"):format(shown, tostring(derr))
            elseif rec.format ~= 1 then recFileErr = recFileErr or ("%s has format %s: this runner reads format 1"):format(shown, tostring(rec.format))
            else for label, call in pairs(type(rec.calls) == "table" and rec.calls or {}) do calls[label] = call end end
        end
        read(root .. "/tools/recordings/" .. surface.client .. ".json", "tools/recordings/" .. surface.client .. ".json")
        if type(spec.recordings) == "string" then read(pathJoin(root, spec.recordings) .. "/" .. surface.client .. ".json", spec.recordings .. "/" .. surface.client .. ".json") end
        surface.recordings = { calls = calls }
    end
    fillMocks(spec.mocks); for _, g in ipairs(groups) do fillMocks(g.mocks) end
    local absent
    if surface then
        for _, api in ipairs(mockNames) do
            local ns, member = api:match("^([^%.]+)%.(.+)$")
            local has = ns and surface.namespaces[ns] and surface.namespaces[ns][member] or (not ns and surface.functions[api])
            if not has then absent = api; break end
        end
    end

    local function stopLoad()
        if cur.unhide then cur.unhide(); cur.unhide = nil end
        if cur.stopNil then
            for _, n in ipairs(cur.stopNil()) do
                if not (opts.checkThat and n == "CheckThat") then nilSeen[n] = true end -- ct test chose whether CheckThat is there
            end
            cur.stopNil = nil
        end
        if cur.saved then restoreMocks(cur.saved); cur.saved = nil end
    end

    -- Fires an event at each frame that registered it. Returns the number of frames, or nil and the error.
    local function fire(ev, ...)
        local fired = 0
        for _, f in ipairs(cur.st.frames) do -- ipairs: a frame a handler creates gets the event too, as before
            local evs, units = rawget(f, "events"), rawget(f, "units")
            local forUnit = not (units and units[ev]) or units[ev][(...)]
            if type(evs) == "table" and evs[ev] and forUnit and f.scripts.OnEvent then
                local ok, err = H.budgeted(strict and H.DEFAULT_BUDGET or nil, f.scripts.OnEvent, f, ev, ...) -- the script-time budget is level 5
                fired = fired + 1
                if not ok then return nil, tostring(err) end
            end
        end
        return fired
    end
    local function login(reloading)
        -- Measured in game on Era and Forever (docs/contracts.md): VARIABLES_LOADED comes after ADDON_LOADED and before PLAYER_LOGIN,
        -- and SPELLS_CHANGED after PLAYER_ENTERING_WORLD. Five UPDATE_BINDINGS fire as well; they are not played.
        local events = { { "ADDON_LOADED", name, hasBindings and true or false, n = 3 }, { "VARIABLES_LOADED" }, { "PLAYER_LOGIN" },
            { "PLAYER_ENTERING_WORLD", not reloading, reloading and true or false, n = 3 }, { "SPELLS_CHANGED" } }
        for _, e in ipairs(events) do
            if e[1] == "PLAYER_LOGIN" then cur.st.loggedIn = true end
            local n, err = fire(unpack(e, 1, e.n or #e)) -- exactly the values the game passes: none for VARIABLES_LOADED
            if not n then return false, ("%s handler threw %s"):format(e[1], err) end
            if e[1] == "ADDON_LOADED" and opts.checkThat == "late" then
                -- CheckThat loads after the addon. In game it sets its global in its own ADDON_LOADED handler (AceAddon's OnInitialize);
                -- which frame gets that event first is not measured, so the addon's handlers get it before the global is there.
                n, err = fire("ADDON_LOADED", "CheckThat", ctBindings)
                if not n then return false, ("ADDON_LOADED handler threw %s"):format(err) end
                _G.CheckThat = cur.api
            end
        end
        return true
    end

    local clockStart -- GetTime goes on across a reload; a group starts again at 1
    local function client()
        local st = H.stubClient({ taint = level >= 6, scriptBudget = strict and H.DEFAULT_BUDGET or nil, toc = level >= 2 and tocIface() or nil, allInsecure = level < 2, loggedIn = not lifecycle,
            clock = timed and { start = clockStart } or nil, client = surface })
        interface = select(4, _G.GetBuildInfo())
        return st
    end

    -- One load of the addon. sv is what the saved-variables file holds; mocks and counts belong to the group.
    local function load(chunks, mocks, counts, sv, reloading)
        if loads > 0 then stopLoad(); restoreGlobals() end
        loads = loads + 1
        local st = client()
        cur = { st = st, entries = {}, counts = counts, saved = {}, mocks = mocks, facts = {}, runErrs = {} }
        plainCreate = _G.CreateFrame
        -- What the shared fake client lacked: a record of the events a frame registered.
        local create = _G.CreateFrame
        _G.CreateFrame = function(...)
            local f = create(...)
            f.events = {}
            rawset(f, "RegisterEvent", function(self, ev) self.events[ev] = true end)
            if lifecycle then rawset(f, "UnregisterEvent", function(self, ev) self.events[ev] = nil end) end
            if timed then -- the client refuses an event it does not have
                local function register(self, ev)
                    if not events[ev] then error(("Frame:RegisterEvent(): Attempt to register unknown event \"%s\""):format(tostring(ev)), 3) end
                    self.events[ev] = true
                end
                rawset(f, "RegisterEvent", function(self, ev) register(self, ev); local u = rawget(self, "units"); if u then u[ev] = nil end end)
                -- A unit event reaches the frame only for its units: the first value of the event names the unit.
                rawset(f, "RegisterUnitEvent", function(self, ev, ...)
                    register(self, ev)
                    local units = {}
                    for i = 1, select("#", ...) do local u = select(i, ...); if u then units[u] = true end end
                    if next(units) then local u = rawget(self, "units") or {}; rawset(self, "units", u); u[ev] = units end
                end)
            end
            return f
        end
        if opts.prepare then opts.prepare(H, st) end
        oldCT = _G.CheckThat
        local entries, facts = cur.entries, cur.facts
        if opts.checkThat then -- ct test: CheckThat's own API, there before the addon (early), after it (late) or not at all (missing)
            cur.api = opts.checkThat ~= "missing" and realCheckThat() or nil
            _G.CheckThat = opts.checkThat == "early" and cur.api or nil
        else _G.CheckThat = {
            PROTOTYPE = true,
            Entry = function(addon, ename, fn)
                -- The same rules as CheckThat.Entry in the game (CheckThat/Model/Entries.lua).
                if type(addon) ~= "string" or #addon < 1 or #addon > 32 or addon:find("[^%w_%-]")
                    or type(ename) ~= "string" or #ename < 1 or #ename > 42 or ename:find("[^%w_%.%-]") or type(fn) ~= "function" then return false end
                entries[addon] = entries[addon] or {}
                entries[addon][ename] = fn
                return true
            end,
            API_VERSION = 2,
            Report = function(addon, key, value)
                local line = ("[%s] %s=%s"):format(addon, key, tostring(value))
                reports[#reports + 1] = line
                facts[#facts + 1] = line
                return true
            end,
        } end
        local function assign()
            for n, v in pairs(sv or {}) do rawset(_G, n, savedCopy(v)) end
        end
        if lifecycle then
            for n in pairs(declared) do rawset(_G, n, nil) end
            if meta.savedVariablesFirst then assign() end
        end
        local skip = { "/libs/", "/libraries/" }
        local hooksFile = opts.hooksFile or spec.hooks -- ct test names its test file in opts.hooksFile
        if type(hooksFile) == "string" then -- a hooks file inside the addon folder is test code: its nil reads are not the addon's
            local hp = pathJoin(root, hooksFile)
            if hp:sub(1, #folder + 1) == folder .. "/" then skip[#skip + 1] = "/" .. hp:sub(#folder + 2):lower() end
        end
        if type(opts.testDir) == "string" then -- ct test: the addon's whole tests folder (helpers too) is test code
            local td = pathJoin(root, opts.testDir)
            if td:sub(1, #folder + 1) == folder .. "/" then skip[#skip + 1] = "/" .. td:sub(#folder + 2):lower() .. "/" end
        end
        cur.stopNil = H.recordNilReads({ "@" .. folder .. "/" }, skip)
        cur.unhide = hideGlobals()
        local ns = {}
        cur.ns = ns -- a hook's ctx.ns: the namespace of this load
        local ok, err
        local lok, lerr = xpcall(function()
            if spec.mockAfterLoad then
                ok, err = runChunks(chunks, name, ns)
                applyMocks(mocks, counts, cur.saved)
            else
                applyMocks(mocks, counts, cur.saved)
                ok, err = runChunks(chunks, name, ns)
            end
            if ok and lifecycle then
                if not meta.savedVariablesFirst then assign() end
                ok, err = login(reloading)
            end
        end, tostring)
        if not lok then return false, "the runner failed while loading: " .. lerr end
        if ok and opts.loaded then -- test code: it runs with the hidden globals back, and its error fails the load
            cur.unhide()
            local cok, cerr = xpcall(function() opts.loaded(ns, st, loads) end, debug.traceback)
            cur.unhide = hideGlobals()
            if not cok then return false, "opts.loaded failed: " .. tostring(cerr) end
        end
        return ok, err
    end

    -- The hook context (ctx), the first public fake-client API: fields are only added, never removed or changed in meaning.
    -- A hook is test code, so the globals hidden from addon code are back while it runs.
    -- While a hook runs the hidden names hold the host's values (lend); the addon's own values, such as an ffi it set, go back after
    -- it (giveBack). Addon code a hook runs through ctx.fire and ctx.advance gets the addon's values for that time (asAddon).
    local lent
    local function lend() lent = {}; for _, n in ipairs(Runner.HIDDEN) do lent[n] = rawget(_G, n); rawset(_G, n, host[n]) end end
    local function giveBack() for _, n in ipairs(Runner.HIDDEN) do rawset(_G, n, lent[n]) end; lent = nil end
    local function asAddon(f, ...)
        if not lent then return f(...) end -- already addon code: a handler or timer that ctx.fire or ctx.advance runs
        giveBack()
        local r = pack(pcall(f, ...))
        lend()
        if not r[1] then error(r[2], 0) end
        return unpack(r, 2, r.n)
    end
    local reloadNow -- the game's reload, as a reload step does it; set once chunks is known
    local function ctxFor(counts, mocks)
        local function differ(a, b, path, seen)
            if type(a) ~= type(b) or type(a) ~= "table" then
                if a ~= b then return path, a, b end
                return nil
            end
            if seen[a] == b then return nil end -- a table that refers back to itself is compared once
            seen[a] = b
            for k, v in pairs(b) do local p, x, y = differ(a[k], v, path .. "." .. tostring(k), seen); if p then return p, x, y end end
            for k, v in pairs(a) do if b[k] == nil then return path .. "." .. tostring(k), v, nil end end
            return nil
        end
        local ctx
        ctx = {
            ns = cur.ns, client = surface and surface.client, level = level,
            fire = function(ev, ...)
                if events then -- level 4 and up: the same check as an event step
                    local p = eventProblem(ev, select("#", ...), "ctx.fire")
                    if p then error(p, 2) end
                end
                local n, ferr = asAddon(fire, ev, ...)
                if not n then error(("%s handler threw %s"):format(tostring(ev), tostring(ferr)), 2) end
                return n
            end,
            combat = function(on) cur.st.setCombat(on) end,
            advance = function(seconds)
                local ran, werr = asAddon(cur.st.advance, seconds)
                if werr then error(("a timer callback threw %s"):format(tostring(werr)), 2) end
                return ran
            end,
            mockCalls = function(api) return counts[api] or 0 end,
            eq = function(got, want, what)
                if got ~= want then error(("%s: expected %s, got %s"):format(what or "value", tostring(want), tostring(got)), 2) end
            end,
            same = function(got, want, what)
                local p, x, y = differ(got, want, what or "value", {})
                if p then error(("%s: expected %s, got %s"):format(p, tostring(y), tostring(x)), 2) end
            end,
            ok = function(v, what)
                if not v then error(("%s: expected a true value, got %s"):format(what or "value", tostring(v)), 2) end
            end,
            -- fn must raise, with the plain text in its error when text is given. Returns the error.
            raises = function(fn, text, what)
                local rok, rerr = pcall(fn)
                if rok then error(("%s: expected an error, the call returned"):format(what or "raises"), 2) end
                if text ~= nil and not tostring(rerr):find(tostring(text), 1, true) then
                    error(("%s: expected an error containing %q, got %q"):format(what or "raises", tostring(text), tostring(rerr)), 2)
                end
                return rerr
            end,
            -- Calls the entry the addon registered under its name, as addon code, and returns its values; nil when there is none.
            entry = function(ename, ...)
                local fn = cur.entries[name] and cur.entries[name][ename]
                if not fn then return nil end
                local ic = rawget(_G, "InCombatLockdown")
                if ic and ic() then error(("entry %s is refused in combat, as a plan's call is"):format(tostring(ename)), 2) end
                local r = pack(asAddon(H.budgeted, strict and H.DEFAULT_BUDGET or nil, fn, ...)) -- the script-time budget, as for a handler
                if not r[1] then error(("entry %s threw %s"):format(tostring(ename), tostring(r[2])), 2) end
                return unpack(r, 2, r.n)
            end,
            -- The fact lines Report recorded in this load (with ct test, only while a run is open, as in game).
            reports = function()
                local c = {}
                for i, l in ipairs(cur.facts or {}) do c[i] = l end
                return c
            end,
            -- Opens ("start") or ends ("end") a run of a plan for the addon, as CheckThat does in game: OnRun gets the event, ActiveRun
            -- answers, Report records. A start while a run is open ends that one first ("replaced").
            run = function(event, info)
                if not opts.checkThat then error("ctx.run needs CheckThat's own API, which ct test gives; an offline block has the older fake", 2) end
                if event ~= "start" and event ~= "end" then error('ctx.run: the event is "start" or "end", got ' .. tostring(event), 2) end
                if info ~= nil and type(info) ~= "table" then error("ctx.run: info is a table", 2) end
                info = info or {}
                local before, reason = openRun, "replaced"
                if event == "start" then
                    openRun = { addon = info.addon or name, planTitle = info.plan or "Test plan", planDigest = info.digest or "00000000",
                        runId = info.runId or "ct-test-1" }
                else
                    if not openRun then error("ctx.run: no run is open", 2) end
                    reason = info.reason or "ended"
                    if reason ~= "ended" and reason ~= "replaced" and reason ~= "deleted" then
                        error("ctx.run: the reason is ended, replaced or deleted, got " .. tostring(reason), 2)
                    end
                    openRun = nil
                end
                local errs = #cur.runErrs
                if cur.api then
                    local cok, cerr = asAddon(H.budgeted, strict and H.DEFAULT_BUDGET or nil, cur.runEvents.Changed, before, openRun, reason)
                    if not cok then error("the addon's OnRun function raised " .. tostring(cerr), 2) end
                end
                if #cur.runErrs > errs then error("the addon's OnRun function raised " .. table.concat(cur.runErrs, "; ", errs + 1), 2) end
            end,
            -- The game's reload, as a reload step does it (hooks run at level 5 and up): ctx.ns then names the new load's namespace.
            reload = function()
                if not lent then error("ctx.reload runs from the test or hook itself, not from a handler or timer it fires", 2) end
                local rok, rerr = asAddon(reloadNow, mocks, counts)
                if not rok then error("the reload failed: " .. tostring(rerr), 2) end
                ctx.ns = cur.ns
                -- An open run sends start again when the addon registers in the new load.
                if #(cur.runErrs or {}) > 0 then error("the addon's OnRun function raised at the reload: " .. table.concat(cur.runErrs, "; "), 2) end
            end,
        }
        return ctx
    end
    local function runHook(name, args, counts, mocks)
        lend()
        local r = pack(pcall(hooks[name], ctxFor(counts, mocks), unpack(args, 1, #args)))
        giveBack()
        return r
    end

    local chunks, loadErr
    reloadNow = function(mocks, counts)
        for _, ev in ipairs({ { "PLAYER_LEAVING_WORLD" }, { "ADDONS_UNLOADING", false }, { "PLAYER_LOGOUT" } }) do -- measured order
            local n, ferr = fire(unpack(ev, 1, #ev))
            if not n then return false, ("%s handler threw %s"):format(ev[1], ferr) end
        end
        clockStart = cur.st.now
        local saved = {}
        for n in pairs(declared) do saved[n] = savedCopy(rawget(_G, n)) end
        return load(chunks, mocks, counts, saved, true)
    end
    if badLevel then
        loadErr = ("offline level %s is not supported (this runner knows 1 to %d)"):format(tostring(spec.level), Runner.LEVEL)
    elseif spec.groups and spec.steps then
        loadErr = "a block holds steps or groups, not both"
    elseif spec.groups and (type(spec.groups) ~= "table" or #spec.groups == 0) then
        loadErr = "groups is empty"
    elseif needs3 and level < 3 then
        loadErr = ("%s needs offline level 3"):format(needs3)
    elseif needs4 and level < 4 then
        loadErr = ("%s needs offline level 4"):format(needs4)
    elseif needs5 and level < 5 then
        loadErr = ("%s needs offline level 5"):format(needs5)
    elseif eventsErr then
        loadErr = eventsErr
    elseif surfaceErr then
        loadErr = surfaceErr
    elseif undeclared then
        loadErr = ("savedVariables names %s, which the TOC does not declare"):format(undeclared)
    elseif recErr then
        loadErr = recErr
    elseif unlisted then
        loadErr = ("mock %s is not on the allow list"):format(unlisted)
    elseif absent then
        loadErr = ("mock %s: the %s client has no such function"):format(absent, surface.client)
    else
        loadErr = loadHooks()
        if not loadErr then chunks, loadErr = compileToc(Lua51, H, tocPath) end
    end
    if not chunks then -- no load: the fake client is still built once, as before, for the caller's prepare
        cur = { st = client() }
        plainCreate = _G.CreateFrame
        if opts.prepare then opts.prepare(H, cur.st) end
        oldCT = _G.CheckThat
    end

    local mockCalls = {}
    if loadErr and #groups == 0 then groups = { {} } end -- one load result says why
    for gi, g in ipairs(groups) do
        local function add(i, kind, ok, detail)
            if cur.st and cur.st.checkTaint then cur.st.checkTaint() end -- level 6: a replaced game global latches at the end of a step
            results[#results + 1] = { step = i, group = grouped and gi or nil, kind = kind, ok = ok and true or false,
                detail = detail, mocked = next(cur.mocks or {}) ~= nil }
        end
        local mocks = {}
        for api, r in pairs(spec.mocks or {}) do mocks[api] = r end
        for api, r in pairs(g.mocks or {}) do mocks[api] = r end
        local counts = {}
        mockCalls[gi] = counts
        clockStart = nil
        local ok, err = false, loadErr
        if chunks then ok, err = load(chunks, mocks, counts, g.savedVariables or spec.savedVariables, false) end
        if not ok then
            add(0, "load", false, err)
            if not chunks then break end
        else
            local at = 0
            local sok, serr = xpcall(function()
            local steps = g.steps or {}
            for i, step in ipairs(steps) do
                at = i
                if step.call then
                    local entries = cur.entries
                    local fn = entries[step.call.addon] and entries[step.call.addon][step.call.entry]
                    if not fn then
                        add(i, "call", false, ("entry %s.%s is not registered"):format(tostring(step.call.addon), tostring(step.call.entry)))
                    else
                        local args = step.call.args or {}
                        local r = pack(pcall(fn, unpack(args, 1, #args)))
                        if step.throws ~= nil then
                            if r[1] then add(i, "call", false, "expected a throw, got " .. show({ n = r.n - 1, unpack(r, 2, r.n) }))
                            elseif tostring(r[2]):find(step.throws, 1, true) then add(i, "call", true, tostring(r[2]))
                            else add(i, "call", false, ("threw %q, expected text %q"):format(tostring(r[2]), step.throws)) end
                        elseif not r[1] then
                            add(i, "call", false, "threw " .. tostring(r[2]))
                        else
                            local got = { n = r.n - 1, unpack(r, 2, r.n) }
                            if step.returns == nil then add(i, "call", true, "returned " .. show(got))
                            elseif sameList(got, step.returns) then add(i, "call", true, "returned " .. show(got))
                            else add(i, "call", false, ("returned %s, expected %s"):format(show(got), show(step.returns))) end
                        end
                    end
                elseif step.event then
                    local ev = step.event
                    local fired, ferr = fire(ev.name, unpack(ev.args or {}, 1, #(ev.args or {})))
                    if not fired then add(i, "event", false, "handler threw " .. ferr)
                    elseif fired == 0 then add(i, "event", false, "no frame registered " .. tostring(ev.name))
                    else add(i, "event", true, ("fired at %d frame(s)"):format(fired)) end
                elseif step.mockCalls then
                    local n = counts[step.mockCalls.api] or 0
                    add(i, "mockCalls", n == step.mockCalls.count, ("%s called %d time(s), expected %d"):format(step.mockCalls.api, n, step.mockCalls.count))
                elseif step.wait ~= nil then
                    local ran, werr = cur.st.advance(step.wait)
                    if werr then add(i, "wait", false, ("a timer callback threw %s"):format(werr))
                    else add(i, "wait", true, ("waited %ss, ran %d timer callback(s)"):format(tostring(step.wait), ran)) end
                elseif step.reload then
                    local rok, rerr = reloadNow(mocks, counts)
                    add(i, "reload", rok, rok and "reloaded" or rerr)
                    if not rok then
                        for j = i + 1, #steps do add(j, "skipped", false, "not run: the reload failed") end
                        break
                    end
                elseif step.hook ~= nil then
                    local r = runHook(step.hook, step.args or {}, counts, mocks)
                    if step.throws ~= nil then
                        if r[1] then add(i, "hook", false, "expected a throw, got " .. show({ n = r.n - 1, unpack(r, 2, r.n) }))
                        elseif tostring(r[2]):find(step.throws, 1, true) then add(i, "hook", true, tostring(r[2]))
                        else add(i, "hook", false, ("threw %q, expected text %q"):format(tostring(r[2]), step.throws)) end
                    elseif not r[1] then
                        add(i, "hook", false, "threw " .. tostring(r[2]))
                    else
                        local got = { n = r.n - 1, unpack(r, 2, r.n) }
                        if step.returns == nil or sameList(got, step.returns) then add(i, "hook", true, "returned " .. show(got))
                        else add(i, "hook", false, ("returned %s, expected %s"):format(show(got), show(step.returns))) end
                    end
                elseif step.tooltip then
                    local t, lines = step.tooltip, H.tooltipLines(rawget(_G, "GameTooltip"))
                    local function has(l) -- a line matches by its left or right text
                        for _, side in ipairs({ "left", "right" }) do
                            local s = l[side]
                            if s ~= nil and ((t.equals ~= nil and s == t.equals) or (t.contains ~= nil and tostring(s):find(t.contains, 1, true))) then return true end
                        end
                        return false
                    end
                    local fmtLine = function(l) return ("%s | %s"):format(tostring(l.left), tostring(l.right)) end
                    if not lines then
                        add(i, "tooltip", false, rawget(_G, "GameTooltip") == nil and "there is no GameTooltip: the client has none at this level"
                            or "GameTooltip is not the client's tooltip: a mock or the addon replaced it, so there are no lines to read")
                    elseif t.lines ~= nil then add(i, "tooltip", #lines == t.lines, ("the tooltip has %d line(s), expected %d"):format(#lines, t.lines))
                    elseif t.line ~= nil then
                        local l = lines[t.line]
                        if not l then add(i, "tooltip", false, ("the tooltip has %d line(s), so there is no line %d"):format(#lines, t.line))
                        elseif has(l) then add(i, "tooltip", true, ("line %d is %s"):format(t.line, fmtLine(l)))
                        else add(i, "tooltip", false, ("line %d is %s, expected %s %q"):format(t.line, fmtLine(l), t.equals ~= nil and "equals" or "contains", t.equals or t.contains)) end
                    else
                        local hit
                        for n, l in ipairs(lines) do if has(l) then hit = n; break end end
                        local shown = {}
                        for n, l in ipairs(lines) do shown[n] = l.right and (tostring(l.left) .. " | " .. tostring(l.right)) or tostring(l.left) end
                        if hit then add(i, "tooltip", true, ("line %d matches"):format(hit))
                        else add(i, "tooltip", false, ("no line %s %q; the lines are %s"):format(t.equals ~= nil and "equals" or "contains", t.equals or t.contains, show(shown))) end
                    end
                else
                    add(i, "unknown", false, "step has no call, event, mockCalls, wait, tooltip, hook or reload")
                end
            end
            end, tostring)
            if not sok then add(at, "error", false, "the runner failed: " .. serr) end
        end
    end

    stopLoad()
    _G.CheckThat = oldCT
    _G.CreateFrame = plainCreate
    -- Level 3 puts the global table back as the run found it, so a later run in the same process starts clean (its
    -- LibStub and libraries included). Levels 1 and 2 leave the fake client in place, as they always did.
    if lifecycle then restoreGlobals() end
    local nilReads = {}
    for n in pairs(nilSeen) do nilReads[#nilReads + 1] = n end
    table.sort(nilReads)
    local ok = true
    for _, r in ipairs(results) do if not r.ok then ok = false end end
    local want = 0
    for _, g in ipairs(groups) do want = want + math.max(#(g.steps or {}), 0) end
    local steps = 0
    for _, r in ipairs(results) do if r.step > 0 then steps = steps + 1 end end
    if chunks and steps ~= want then ok = false end
    return { ok = ok, level = level, interface = interface, nilReads = nilReads, mocks = mockNames,
        mockCalls = grouped and mockCalls or mockCalls[1] or {}, reports = reports, steps = results }, jns.Json
end

local function main()
    local here = arg[0]:match("^(.*)/tools/[^/]*$") or "."
    local f = assert(io.open(arg[1], "r")); local text = f:read("*a"); f:close()
    local jns = {}
    assert(loadfile(here .. "/CheckThat/Model/Json.lua"))("CheckThat", jns)
    local spec, err = jns.Json.Decode(text)
    if not spec then io.stderr:write(err, "\n"); os.exit(2) end
    local result, Json = Runner.run(spec, { root = here })
    io.write(Json.Encode(result), "\n")
    os.exit(result.ok and 0 or 1)
end

if arg and arg[0] and arg[0]:find("entry_runner%.lua$") then main() end
return Runner
