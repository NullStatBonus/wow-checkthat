-- Shared test setup. Each tests/test_*.lua starts with:
--   local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- and ends with finish(). Run one file with: luajit tests/test_json.lua   (from the repository root).
local H = {}
local rawprint = print

-- A frame made from a Secure*Template is protected. Insecure code may not change it in combat, and the game
-- refuses to anchor it to anything but the screen (measured on Forever, docs/contracts.md).
local BLOCKED_IN_COMBAT = { SetAttribute = true, Show = true, Hide = true, SetShown = true, SetPoint = true,
    ClearAllPoints = true, SetSize = true, SetWidth = true, SetHeight = true, SetParent = true, SetScale = true }
local function inCombat() return _G.InCombatLockdown and _G.InCombatLockdown() end

-- Show and Hide run the OnShow and OnHide scripts and hooks, once for each real change.
local function setShown(f, v)
    v = v and true or false
    if f.shown == v then return end
    f.shown = v
    local ev = v and "OnShow" or "OnHide"
    if f.scripts[ev] then f.scripts[ev](f) end
    for _, fn in ipairs(f.hooks[ev] or {}) do fn(f) end
end

local stubFrame
local function member(frames, k)
    if k == "SetScript" then return function(self, ev, fn) self.scripts[ev] = fn end end
    if k == "HookScript" then return function(self, ev, fn) self.hooks[ev] = self.hooks[ev] or {}; table.insert(self.hooks[ev], fn) end end
    if k == "SetAttribute" then return function(self, a, v) self.attrs[a] = v end end
    if k == "Show" then return function(self) setShown(self, true) end end
    if k == "Hide" then return function(self) setShown(self, false) end end
    if k == "IsShown" or k == "IsVisible" then return function(self) return self.shown end end
    if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
    if k == "GetStringHeight" then return function() return 40 end end
    if k == "GetStringWidth" then return function() return 80 end end
    if k == "GetText" then return function(self) return self.text or "" end end
    if k == "SetText" then return function(self, v) self.text = v end end
    if k == "SetShown" then return function(self, v) setShown(self, v) end end
    if k == "GetWidth" or k == "GetHeight" then return function() return 100 end end
    if k == "CreateFontString" or k == "CreateTexture" or k == "CreateAnimationGroup" then return function() return stubFrame(frames) end end
    -- chainable: GetNormalTexture():SetTexCoord() works. The last arguments of each call are kept in .calls.
    return function(self, ...)
        rawset(self, "calls", rawget(self, "calls") or {})
        self.calls[k] = { n = select("#", ...), ... }
        return stubFrame(frames)
    end
end

function stubFrame(frames, template, name)
    local f = { shown = true, scripts = {}, hooks = {}, attrs = {}, drivers = {}, template = template, name = name }
    f.protected = (template and template:find("Secure", 1, true)) and true or false
    frames[#frames + 1] = f
    return setmetatable(f, { __index = function(t, k)
        local fn = member(frames, k)
        if not (f.protected and BLOCKED_IN_COMBAT[k]) then return fn end
        return function(self, ...)
            if inCombat() then
                error(("Interface action failed because of an AddOn: %s on protected frame %s in combat"):format(k, tostring(self.name)), 2)
            end
            if k == "SetPoint" then
                local rel = select(2, ...)
                if rel ~= nil and rel ~= _G.UIParent then error("Cannot anchor protected frames to regions", 2) end
            end
            return fn(self, ...)
        end
    end })
end

-- A stub game client: enough API for the real Ace libraries and the addon files to load and run.
function H.stubClient(opts)
    opts = opts or {}
    local st = { frames = {}, said = {}, combat = false, macros = {} }
    _G.CreateFrame = function(_, name, _, template) local f = stubFrame(st.frames, template, name); if name then _G[name] = f end; return f end
    _G.UIParent = stubFrame(st.frames)
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) st.said[#st.said + 1] = m end }
    _G.InCombatLockdown = function() return st.combat end
    _G.GetBuildInfo = function() return "1.15.7", "63000", "x", opts.toc or 11507 end
    _G.UnitName = function() return opts.name or "Tester" end
    _G.GetRealmName = function() return "Realm" end
    _G.ReloadUI = function() st.reloaded = true end
    _G.GetMacroIndexByName = function(n) return st.macros[n] and 1 or 0 end
    _G.GetMacroInfo = function(i) return "n", "i", st.macroBody end
    _G.CreateMacro = function(n, _, body) st.macros[n] = true; st.macroBody = body end
    _G.EditMacro = function(_, _, _, body) st.macroBody = body end
    _G.SlashCmdList = {}
    _G.UISpecialFrames = {}
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which) st.popup = _G.StaticPopupDialogs[which] end
    -- The error handler is one global slot, as in the game: seterrorhandler replaces it.
    local handler = function(e) error(e, 0) end
    st.errors = {}
    _G.geterrorhandler = function() return handler end
    _G.seterrorhandler = function(fn) handler = fn end
    _G.GetTime = function() return 1 end
    st.timers = {}
    _G.C_Timer = { After = function(_, fn) st.timers[#st.timers + 1] = fn end } -- queued; a test runs them
    -- The secure state driver: [combat] hide; show. The game applies it with its own privileges, also in combat,
-- and applies it again about five times a second. st.tick() is one such pass.
local function applyDriver(f)
    local cond = f.drivers.visibility
    if not cond then return end
    local fn = cond:find("[combat] hide", 1, true) and (st.combat and "hide" or "show") or "show"
    setShown(f, fn == "show")
end
_G.RegisterStateDriver = function(f, state, cond) f.drivers[state] = cond; applyDriver(f) end
_G.UnregisterStateDriver = function(f, state) f.drivers[state] = nil end
function st.tick() for _, f in ipairs(st.frames) do applyDriver(f) end end
function st.setCombat(v) st.combat = v and true or false; st.tick() end
-- What a click on a secure macro button runs: its macro text, or nil when the player cannot click it.
function st.click(f)
    if not f.shown or f.attrs.type ~= "macro" then return nil end
    return f.attrs.macrotext
end
-- The game's own names are secure: here, every global the fake client set up before addon code ran (st.secure, taken at
-- the end of stubClient). A member of any other table counts as secure.
-- opts.allInsecure keeps the answer of offline level 1: false for every name.
_G.issecurevariable = function(t, k)
    if opts.allInsecure then return false end
    local name = t
    if type(t) == "table" then if t ~= _G then return true end; name = k end
    if st.secure and st.secure[name] then return true end
    return false, "Addon"
end
    _G.securecallfunction = function(f, ...) return f(...) end
    _G.print = function(...) st.said[#st.said + 1] = table.concat({ ... }, " ") end
    _G.strsplit = _G.strsplit or function(d, s, n) local out = {}; for part in (s .. d):gmatch("(.-)" .. d:gsub("%p", "%%%0")) do out[#out + 1] = part end; return unpack(out) end
    _G.wipe = _G.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.UnitFactionGroup = function() return "Alliance", "Alliance" end
    _G.UnitClass = function() return "Warrior", "WARRIOR", 1 end
    _G.UnitRace = function() return "Human", "Human", 1 end
    _G.GetLocale = function() return "enUS" end
    _G.strlenutf8 = function(s) return #s end
    _G.GetCurrentRegion = _G.GetCurrentRegion or function() return 1 end
    _G.GetCurrentRegionName = function() return "US" end
    _G.UnitNameUnmodified = function() return opts.name or "Tester", nil end
    _G.GetNormalizedRealmName = function() return "Realm" end
    _G.IsLoggedIn = function() return true end
    _G.tinsert, _G.tremove = table.insert, table.remove
    _G.format = string.format
    _G.max, _G.min, _G.floor = math.max, math.min, math.floor
    st.secure = {}
    for k in pairs(_G) do st.secure[k] = true end
    return st
end

-- Loads CheckThat/<name>.lua with the addon's own (name, ns) arguments.
function H.module(ns, name)
    local chunk = assert(loadfile("CheckThat/" .. name .. ".lua"))
    chunk("CheckThat", ns)
end

-- Plain modules, in TOC order: everything that needs no frames.
function H.plain(ns)
    assert(loadfile("CheckThat/Libs/LibStub/LibStub.lua"))()
    assert(loadfile("CheckThat/Libs/LibDeflate/LibDeflate.lua"))()
    ns.LibDeflate = LibStub("LibDeflate")
    for _, m in ipairs({ "Locales/enUS", "Core/Init", "Core/Adapter", "Core/Defaults", "Model/Json", "Model/Codec", "Model/Plan",
        "Model/Evidence", "Model/Facts", "Model/Entries", "Model/Errors", "Model/Run", "Model/App", "Core/Settings", "Debug/Log", "Core/Slash" }) do
        H.module(ns, m)
    end
end

-- The Lua files a TOC loads, in order, following Script and Include entries of the XML files it lists (paths
-- relative to each XML file, as in the game). Returns nil, err for a path that leaves the addon folder or an XML
-- file that cannot be read; the whole list is built before anything runs.
function H.tocFiles(toc)
    local out = {}
    local function bad(p) return p:find("..", 1, true) or p:match("^[/\\]") or p:match("^%a:") end
    local function add(base, rel)
        rel = rel:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
        if bad(rel) then return nil, "a TOC file path leaves the addon folder: " .. rel end
        local path = base .. "/" .. rel
        if path:match("%.xml$") then
            local f = io.open(path)
            if not f then return nil, "cannot read " .. path end
            local xml = f:read("*a"):gsub("<!%-%-.-%-%->", ""); f:close()
            local dir = path:match("^(.*)/[^/]+$")
            for kind, file in xml:gmatch('<(%a+)%s+file="([^"]+)"') do
                if kind == "Script" or kind == "Include" then
                    local ok, err = add(dir, file)
                    if not ok then return nil, err end
                end
            end
        elseif path:match("%.lua$") then
            out[#out + 1] = path
        end
        return true
    end
    local dir = toc:match("^(.*)/[^/]+$") or "."
    for line in io.lines(toc) do
        line = line:gsub("\r", "")
        if line:match("%S") and not line:match("^%s*#") then
            local ok, err = add(dir, line)
            if not ok then return nil, err end
        end
    end
    return out
end

-- Loads every file a TOC lists, in order, following embeds.xml Script/Include entries.
-- Records the global names that code read as nil. prefixes lists debug source prefixes ("@path/to/folder/") of the
-- code to watch; excludes lists lower-case path pieces to leave out (such as "/libs/"), matched without regard to case. Only string keys count. Returns stop(): it
-- removes the hook, gives back _G's earlier metatable and returns the sorted list of names.
function H.recordNilReads(prefixes, excludes)
    local seen, old = {}, getmetatable(_G)
    local function watched(src) -- excludes are matched in the path below the watched folder, not above it
        for _, p in ipairs(prefixes) do
            if src:sub(1, #p) == p then
                local rest = "/" .. src:sub(#p + 1):lower()
                for _, x in ipairs(excludes or {}) do if rest:find(x, 1, true) then return false end end
                return true
            end
        end
        return false
    end
    local mt = {}
    for k, v in pairs(old or {}) do mt[k] = v end -- keep __newindex and any other field
    mt.__index = function(t, k)
        local oi = old and old.__index
        local v
        if type(oi) == "function" then v = oi(t, k) elseif type(oi) == "table" then v = oi[k] end
        if v ~= nil then return v end -- false counts: only nil falls through
        if type(k) == "string" then
            local info = debug.getinfo(2, "S")
            if info and watched(info.source or "") then seen[k] = true end
        end
        return nil
    end
    setmetatable(_G, mt)
    return function()
        setmetatable(_G, old)
        local list = {}
        for k in pairs(seen) do list[#list + 1] = k end
        table.sort(list)
        return list
    end
end

function H.loadToc(ns, toc)
    for _, path in ipairs(assert(H.tocFiles(toc))) do assert(loadfile(path))("CheckThat", ns) end
end

return function()
    local ns = {}
    local T, fails, pass = {}, 0, 0
    function T.eq(a, b, msg)
        if a ~= b then error(("%s: expected %s, got %s"):format(msg or "eq", tostring(b), tostring(a)), 2) end
    end
    function T.ok(v, msg) if not v then error(msg or "expected truthy", 2) end end
    local function deepEq(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for k, v in pairs(a) do if not deepEq(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end
    T.deepEq = deepEq
    local pattern = arg and arg[1]
    local function test(name, fn)
        if pattern and not name:find(pattern, 1, true) then return end
        local ok, err = pcall(fn)
        if ok then pass = pass + 1 else fails = fails + 1; rawprint("FAIL " .. name .. ": " .. tostring(err)) end
    end
    local function finish()
        rawprint(("%d passed, %d failed"):format(pass, fails))
        os.exit(fails == 0 and 0 or 1)
    end
    ns.__plain = function() H.plain(ns) end
    return ns, test, T, finish, H
end
