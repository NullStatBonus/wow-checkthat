-- Offline runner for addon code. Prototype for issue 94: it reads its own spec file, not a plan.
--
--   luajit tools/entry_runner.lua SPEC.json      (from the repository root; prints the result as JSON)
--
-- SPEC.json: { "toc": "path/Addon.toc", "level": 2,
--              "mocks": { "GetItemInfo": [ {"args": [1], "returns": ["A"]}, {"returns": ["Z"]} ],
--                         "C_Item.GetItemCount": {"returns": [3]} },
--              "mockAfterLoad": false,
--              "steps": [ {"call": {"addon": "A", "entry": "add", "args": [1, 2]}, "returns": [3]},
--                         {"call": {"addon": "A", "entry": "boom"}, "throws": "bad input"},
--                         {"event": {"name": "MERCHANT_SHOW", "args": []}},
--                         {"mockCalls": {"api": "GetItemInfo", "count": 2}} ] }
-- Everything in a spec is data. A step can only call an entry the addon registered through CheckThat.Entry.
-- Mocks are set before the addon loads (a file-scope "local f = f" then sees them) unless mockAfterLoad is set,
-- and the earlier values come back when the run ends. Every step result says whether mocks were in play.
local Runner = {}

-- The newest offline level. A plan without a level runs at level 1, so its results do not change.
Runner.LEVEL = 2

-- The APIs a spec may mock. The runner owns this list; a spec cannot add to it. A name here needs a test.
Runner.MOCKABLE = {}
for _, n in ipairs({ "GetItemInfo", "GetItemCount", "C_Item.GetItemInfo", "C_Item.GetItemCount", "GetMoney", "GetTime",
    "UnitName", "IsInGuild", "GetNumGroupMembers", "GetContainerNumFreeSlots", "C_Container.GetContainerNumFreeSlots",
    "C_Container.GetContainerItemInfo" }) do Runner.MOCKABLE[n] = true end

local function pathJoin(root, p) return p:sub(1, 1) == "/" and p or (root .. "/" .. p) end

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
            if ok then return unpack(rule.returns or {}, 1, #(rule.returns or {})) end
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

-- spec is a decoded table. opts.root is the repository root (default "."); opts.prepare(H, st) runs after the
-- fake client is built, so a test can add the "real" values a mock will replace.
function Runner.run(spec, opts)
    opts = opts or {}
    local root = opts.root or "."
    local jns = {}
    assert(loadfile(root .. "/CheckThat/Model/Json.lua"))("CheckThat", jns)
    local _, _, _, _, H = dofile(root .. "/tests/harness.lua")()
    local Lua51 = dofile(root .. "/tools/lua51_check.lua")
    local tocPath = pathJoin(root, spec.toc)
    -- Offline level: what a plan opted in to. Level 1 (no level) keeps the fake client's first answers: interface 11507
    -- and issecurevariable false for every name. Level 2 answers with the TOC's interface and the secure game names.
    local level = spec.level or 1
    local badLevel = type(level) ~= "number" or level % 1 ~= 0 or level < 1 or level > Runner.LEVEL
    if badLevel then level = 1 end
    local st = H.stubClient({ toc = level >= 2 and tocInterface(tocPath) or nil, allInsecure = level < 2 })
    local interface = select(4, _G.GetBuildInfo())
    -- What the shared fake client lacked: a record of the events a frame registered.
    local plainCreate = _G.CreateFrame
    _G.CreateFrame = function(...)
        local f = plainCreate(...)
        f.events = {}
        rawset(f, "RegisterEvent", function(self, ev) self.events[ev] = true end)
        return f
    end
    if opts.prepare then opts.prepare(H, st) end

    local entries, reports = {}, {}
    local oldCT = _G.CheckThat
    _G.CheckThat = {
        PROTOTYPE = true,
        Entry = function(addon, name, fn)
            -- The same rules as CheckThat.Entry in the game (CheckThat/Model/Entries.lua).
            if type(addon) ~= "string" or #addon < 1 or #addon > 32 or addon:find("[^%w_%-]")
                or type(name) ~= "string" or #name < 1 or #name > 42 or name:find("[^%w_%.%-]") or type(fn) ~= "function" then return false end
            entries[addon] = entries[addon] or {}
            entries[addon][name] = fn
            return true
        end,
        API_VERSION = 2,
        Report = function(addon, key, value) reports[#reports + 1] = ("[%s] %s=%s"):format(addon, key, tostring(value)); return true end,
    }

    local counts, saved, results = {}, {}, {}
    local mockNames = {}
    for api in pairs(spec.mocks or {}) do mockNames[#mockNames + 1] = api end
    table.sort(mockNames)
    local hasMocks = #mockNames > 0

    local name = spec.toc:match("([^/]+)/[^/]+%.toc$") or spec.toc:match("([^/]+)%.toc$") or "Addon" -- the game passes the folder name
    local ns = {}
    local loaded, loadErr
    local unlisted
    local folder = tocPath:match("^(.*)/[^/]+$") or "."
    local stopNil, unhide
    for _, api in ipairs(mockNames) do if not Runner.MOCKABLE[api] then unlisted = api; break end end
    if badLevel then
        loaded, loadErr = false, ("offline level %s is not supported (this runner knows 1 to %d)"):format(tostring(spec.level), Runner.LEVEL)
    elseif unlisted then
        loaded, loadErr = false, ("mock %s is not on the allow list"):format(unlisted)
    else
        local chunks, cerr = compileToc(Lua51, H, tocPath)
        if not chunks then
            loaded, loadErr = false, cerr
        else
            stopNil = H.recordNilReads({ "@" .. folder .. "/" }, { "/libs/", "/libraries/" })
            unhide = hideGlobals()
            local lok, lerr = xpcall(function()
                if spec.mockAfterLoad then
                    loaded, loadErr = runChunks(chunks, name, ns)
                    applyMocks(spec.mocks, counts, saved)
                else
                    applyMocks(spec.mocks, counts, saved)
                    loaded, loadErr = runChunks(chunks, name, ns)
                end
            end, tostring)
            if not lok then loaded, loadErr = false, "the runner failed while loading: " .. lerr end
        end
    end

    local function add(i, kind, ok, detail)
        results[#results + 1] = { step = i, kind = kind, ok = ok and true or false, detail = detail, mocked = hasMocks }
    end

    if not loaded then
        add(0, "load", false, loadErr)
    else
        local cur = 0
        local sok, serr = xpcall(function()
        for i, step in ipairs(spec.steps or {}) do
            cur = i
            if step.call then
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
                local fired = 0
                for _, f in ipairs(st.frames) do
                    local evs = rawget(f, "events")
                    if type(evs) == "table" and evs[step.event.name] and f.scripts.OnEvent then
                        local ev = step.event
                        local ok, err = pcall(f.scripts.OnEvent, f, ev.name, unpack(ev.args or {}, 1, #(ev.args or {})))
                        fired = fired + 1
                        if not ok then add(i, "event", false, "handler threw " .. tostring(err)); fired = -1; break end
                    end
                end
                if fired == 0 then add(i, "event", false, "no frame registered " .. tostring(step.event.name))
                elseif fired > 0 then add(i, "event", true, ("fired at %d frame(s)"):format(fired)) end
            elseif step.mockCalls then
                local n = counts[step.mockCalls.api] or 0
                add(i, "mockCalls", n == step.mockCalls.count, ("%s called %d time(s), expected %d"):format(step.mockCalls.api, n, step.mockCalls.count))
            else
                add(i, "unknown", false, "step has no call, event or mockCalls")
            end
        end
        end, tostring)
        if not sok then add(cur, "error", false, "the runner failed: " .. serr) end
    end

    if unhide then unhide() end
    local nilReads = stopNil and stopNil() or {}
    restoreMocks(saved)
    _G.CheckThat = oldCT
    _G.CreateFrame = plainCreate
    local ok = true
    for _, r in ipairs(results) do if not r.ok then ok = false end end
    local nsteps = #(spec.steps or {})
    if loaded and #results ~= nsteps then ok = false end
    return { ok = ok, level = level, interface = interface, nilReads = nilReads, mocks = mockNames, mockCalls = counts, reports = reports, steps = results }, jns.Json
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
