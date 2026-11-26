-- Shared test setup. Each tests/test_*.lua starts with:
--   local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- and ends with finish(). Run one file with: luajit tests/test_json.lua   (from the repository root).
local H = {}
local rawprint = print
-- Read once: a strict client (H.applySurface) removes loadfile and dofile, as the game has neither.
local loadfile = loadfile
local osdate, osclock, ostime0 = os.date, os.clock, os.time

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
-- A GameTooltip frame keeps the lines an addon adds (self.lines = { { left =, right =, color = {r, g, b} } }) and starts hidden,
-- as the game's tooltip does. Not modelled: whether a Set* call shows it, argument checks, the TextLeftN regions and the hook path (#151).
local TOOLTIP = {
    AddLine = function(self, text, r, g, b, wrap) self.lines[#self.lines + 1] = { left = text, color = r and { r, g, b }, wrap = wrap } end,
    AddDoubleLine = function(self, left, right, lr, lg, lb, rr, rg, rb) self.lines[#self.lines + 1] = { left = left, right = right, color = lr and { lr, lg, lb }, rightColor = rr and { rr, rg, rb } } end,
    SetText = function(self, text, r, g, b, _, wrap) self.lines = { { left = text, color = r and { r, g, b }, wrap = wrap } } end,
    ClearLines = function(self) self.lines = {} end,
    NumLines = function(self) return #self.lines end,
    SetOwner = function(self, owner) self.owner = owner; self.lines = {} end,
    GetOwner = function(self) return self.owner end,
    -- An item link or id sets the tooltip to an item and runs the client's item hooks at once (measured). It adds no lines.
    SetHyperlink = function(self, link) self.lines = {}; if type(link) == "string" and link:find("item:", 1, true) then H.itemTooltipSet(self) end end,
    SetItemByID = function(self) self.lines = {}; H.itemTooltipSet(self) end,
}

-- Runs the hooks an item tooltip fires: the OnTooltipSetItem script hooks on a client with the script path, the
-- TooltipDataProcessor post calls for items on one with the processor path (the surface says which: tooltipHooks).
function H.itemTooltipSet(tip)
    local frames = rawget(tip, "_frames")
    local mode = frames and frames.surface and frames.surface.tooltipHooks
    -- A throwing script, hook or post call goes to the error handler and does not stop the tooltip call or the others.
    local function run(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then
            local handler = type(_G.geterrorhandler) == "function" and _G.geterrorhandler()
            if type(handler) == "function" then pcall(handler, err) end
        end
    end
    if mode == "script" or mode == nil then
        if tip.scripts.OnTooltipSetItem then run(tip.scripts.OnTooltipSetItem, tip) end
        for _, fn in ipairs(tip.hooks.OnTooltipSetItem or {}) do run(fn, tip) end
    end
    if mode == "processor" then
        for _, call in ipairs(frames.postCalls or {}) do
            if call.kind == "item" then run(call.fn, tip, { type = "item" }) end
        end
    end
end

-- The lines of a fake GameTooltip as { { left =, right = }, ... } (a copy), or nil when it is not one.
function H.tooltipLines(tip)
    local lines = type(tip) == "table" and rawget(tip, "lines")
    if not lines then return nil end
    local out = {}
    for i, l in ipairs(lines) do out[i] = { left = l.left, right = l.right, color = l.color, rightColor = l.rightColor, wrap = l.wrap } end
    return out
end

local function member(frames, k)
    if k == "SetScript" then return function(self, ev, fn) self.scripts[ev] = fn end end
    if k == "HookScript" then
        return function(self, ev, fn)
            -- A client on the processor path has no OnTooltipSetItem script on its tooltip: registering the hook fails (measured; the message is not).
            if ev == "OnTooltipSetItem" and rawget(self, "lines") and frames.surface and frames.surface.tooltipHooks == "processor" then
                error('Frame:HookScript(): GameTooltip doesn\'t have a "OnTooltipSetItem" script', 2)
            end
            self.hooks[ev] = self.hooks[ev] or {}; table.insert(self.hooks[ev], fn)
        end
    end
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
    if k == "CreateFontString" then return function() return stubFrame(frames, nil, nil, "FontString") end end
    if k == "CreateTexture" then return function() return stubFrame(frames, nil, nil, "Texture") end end
    if k == "CreateAnimationGroup" then return function() return stubFrame(frames) end end
    -- chainable: GetNormalTexture():SetTexCoord() works. The last arguments of each call are kept in .calls.
    return function(self, ...)
        rawset(self, "calls", rawget(self, "calls") or {})
        self.calls[k] = { n = select("#", ...), ... }
        return stubFrame(frames)
    end
end

-- The names a frame of this widget type made from these templates (a comma or space list) answers to: the type's methods, and
-- the methods and child keys of each template the surface lists. Returns the allowed names and the child keys among them. A template the surface does not list (an addon's own, or one
-- nobody read from Blizzard's source) makes the frame take any method, so this returns nil.
function H.templateMethods(surface, kind, template)
    local cache = surface.templateCache
    if not cache then cache = {}; surface.templateCache = cache end
    local key = kind:lower() .. "\0" .. template
    if cache[key] ~= nil then
        if cache[key] == false then return nil end
        return cache[key].methods, cache[key].keys
    end
    local set, keys = {}, {}
    for n in pairs(surface.widgetsByLower[kind:lower()]) do set[n] = true end
    for name in template:gmatch("[^,%s]+") do
        local t = surface.templates and surface.templates[name]
        if not t then cache[key] = false; return nil end
        for n in pairs(t.methods) do set[n] = true end
        for n in pairs(t.keys) do set[n] = true; keys[n] = true end
    end
    cache[key] = { methods = set, keys = keys }
    return set, keys
end

-- kind is the widget type. With a client surface (frames.surface, see H.stubClient), a frame of a listed type has only that
-- type's methods, plus those of its templates when the surface lists every one: any other name reads nil, so a call to it
-- fails as in the game. A frame of a type the surface does not list, or from a template it does not list, takes any method.
function stubFrame(frames, template, name, kind)
    local f = { shown = true, scripts = {}, hooks = {}, attrs = {}, drivers = {}, template = template, name = name, kind = kind }
    f.protected = (template and template:find("Secure", 1, true)) and true or false
    frames[#frames + 1] = f
    if type(kind) == "string" and kind:lower() == "gametooltip" then f.lines = {}; f.shown = false; rawset(f, "_frames", frames) end
    local methods = frames.surface and type(kind) == "string" and frames.surface.widgetsByLower[kind:lower()]
    local keys
    if methods and template then methods, keys = H.templateMethods(frames.surface, kind, template) end
    return setmetatable(f, { __index = function(t, k)
        if keys and keys[k] then -- a child the template makes (Text, ScrollBar): a frame of its own, kept on this one
            local child = stubFrame(frames)
            rawset(t, k, child)
            return child
        end
        if methods and not methods[k] then return nil end
        local fn = rawget(f, "lines") and TOOLTIP[k] or member(frames, k)
        if not (f.protected and BLOCKED_IN_COMBAT[k]) then return fn end
        return function(self, ...)
            if inCombat() then
                error(("Interface action failed because of an AddOn: %s on protected frame %s in combat"):format(k, tostring(self.name)), 2)
            end
            if k == "SetPoint" then
                local rel = select(2, ...)
                if type(rel) == "string" then rel = rawget(_G, rel) end -- a frame name; SetPoint(point, x, y) has no relative frame
                if type(rel) == "table" and rel ~= _G.UIParent then error("Cannot anchor protected frames to regions", 2) end
            end
            return fn(self, ...)
        end
    end })
end

-- Taint of global names (offline level 6, measured in game, docs/contracts.md): a game global that addon code replaces reads as
-- insecure from then on, and putting the original back does not clear it. st.checkTaint() compares each game global with the value
-- it had when the fake client was built and latches a change for good; issecurevariable and the runner call it, the runner
-- also after every step. A replace and a restore inside one step, with no check between, is not seen. hooksecurefunc runs the hook
-- after the original and leaves the name secure. A member of a table stays secure, and a protected action does not read taint
-- yet: ADDON_ACTION_BLOCKED needs an in-game probe of a Blizzard path that reads a tainted global.
function H.taint(st)
    st.tainted = {}
    _G.hooksecurefunc = function(a, b, c)
        local tbl, name, fn = _G, a, b
        if type(a) == "table" then tbl, name, fn = a, b, c end
        local orig = tbl[name]
        if type(name) ~= "string" or type(orig) ~= "function" or type(fn) ~= "function" then
            error('Usage: hooksecurefunc([table,] "function", hookfunc)', 2)
        end
        local function pack(...) return { n = select("#", ...), ... } end
        local function wrapper(...)
            local r = pack(orig(...))
            -- A hook that throws does not change what the original returned: the error goes to the error handler.
            local ok, err = pcall(fn, ...)
            if not ok then
                st.hookErrors = st.hookErrors or {}
                st.hookErrors[#st.hookErrors + 1] = tostring(err)
                local handler = type(_G.geterrorhandler) == "function" and _G.geterrorhandler()
                if type(handler) == "function" then pcall(handler, err) end
            end
            return unpack(r, 1, r.n)
        end
        rawset(tbl, name, wrapper)
        if tbl == _G and st.secureValue and st.secureValue[name] ~= nil then st.secureValue[name] = wrapper end
    end
    function st.checkTaint()
        for name, value in pairs(st.secureValue or {}) do
            if rawget(_G, name) ~= value then st.tainted[name] = true end
        end
    end
end

-- A stub game client: enough API for the real Ace libraries and the addon files to load and run.
function H.stubClient(opts)
    opts = opts or {}
    local st = { frames = {}, said = {}, combat = false, macros = {} }
    local surface = opts.client
    if type(surface) == "string" then surface = assert(H.clientSurface(surface)) end
    st.frames.surface, st.surface = surface, surface
    _G.CreateFrame = function(kind, name, _, template) local f = stubFrame(st.frames, template, name, kind); if name then _G[name] = f end; return f end
    _G.UIParent = stubFrame(st.frames, nil, nil, "Frame")
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
    st.scriptBudget = opts.scriptBudget -- see H.budgeted: applied to timer callbacks
    if opts.clock then H.clock(st, opts.clock) end
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
    if st.checkTaint then st.checkTaint(); if st.tainted[name] then return false, "Addon" end end
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
    st.loggedIn = opts.loggedIn ~= false -- offline level 3 starts logged out and logs in at PLAYER_LOGIN
    _G.IsLoggedIn = function() return st.loggedIn end
    _G.tinsert, _G.tremove = table.insert, table.remove
    _G.format = string.format
    _G.max, _G.min, _G.floor = math.max, math.min, math.floor
    if surface then H.applySurface(st, surface) end
    if opts.taint then H.taint(st) end
    st.secure = {}
    for k in pairs(_G) do st.secure[k] = true end
    if opts.taint then
        st.secureValue = {}
        -- Lua's own names and the libraries the runner hides or puts back while addon code runs are not the game's: leave them out.
        local own = { string = 1, table = 1, math = 1, bit = 1, coroutine = 1, io = 1, os = 1, jit = 1, ffi = 1, debug = 1, package = 1,
            require = 1, dofile = 1, loadfile = 1, load = 1, module = 1 }
        for k in pairs(st.secure) do
            if type(k) == "string" and not own[k] then st.secureValue[k] = rawget(_G, k) end
        end
    end
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
        "Model/Evidence", "Model/Facts", "Model/Entries", "Model/RunEvents", "Model/Errors", "Model/Run", "Model/App", "Core/Settings", "Debug/Log", "Core/Slash" }) do
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

-- A client surface: what one game client defines, from tools/clients/<client>.json (made by tools/client_slice.py from
-- an in-game census). Returns { client, build, interface, functions = set, namespaces = {C_X = set}, widgets = {Type = set},
-- templates = {Name = {methods = set, keys = set}} (from tools/template_slice.py; absent in an older file) }.
function H.clientSurface(client, root)
    root = root or "."
    local jns = {}
    assert(loadfile(root .. "/CheckThat/Model/Json.lua"))("CheckThat", jns)
    local f = io.open(root .. "/tools/clients/" .. client .. ".json", "r")
    if not f then return nil, "no client surface for " .. client .. " (tools/clients/" .. client .. ".json)" end
    local m, err = jns.Json.Decode(f:read("*a")); f:close()
    if not m then return nil, err end
    if m.client ~= client then return nil, ("no client surface for %s (the file says %s)"):format(client, tostring(m.client)) end -- a case-blind file system
    local function set(list) local s = {}; for _, n in ipairs(list) do s[n] = true end; return s end
    local s = { client = m.client, build = m.build, interface = m.interface, functions = set(m.functions), namespaces = {}, widgets = {} }
    s.lacksBase = {}
    for _, n in ipairs({ "dofile", "load", "loadfile", "module", "require" }) do if not s.functions[n] then s.lacksBase[n] = true end end
    for ns, list in pairs(m.namespaces) do s.namespaces[ns] = set(list) end
    s.tooltipHooks = m.tooltipHooks -- "script" (OnTooltipSetItem) or "processor" (TooltipDataProcessor); measured, docs/contracts.md
    s.templates = {}
    for name, t in pairs(m.templates or {}) do s.templates[name] = { methods = set(t.methods or {}), keys = set(t.keys or {}) } end
    s.widgetsByLower = {}
    for w, list in pairs(m.widgets) do s.widgets[w] = set(list); s.widgetsByLower[w:lower()] = s.widgets[w] end -- CreateFrame("frame") works
    return s
end

-- Plain helpers the game defines in Lua and addons rely on: a stub that returns nothing would break them.
local function copyTable(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local c = {}; seen[t] = c
    for k, v in pairs(t) do c[k] = copyTable(v, seen) end
    return c
end
local HELPERS = {
    Mixin = function(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end; return o end,
    CopyTable = function(t) return copyTable(t) end,
    tContains = function(t, v) for _, x in pairs(t) do if x == v then return true end end; return false end,
    strtrim = function(s, chars)
        chars = chars and ("[" .. chars:gsub("[%]%^%-%%]", "%%%0") .. "]") or "%s"
        return (s:gsub("^" .. chars .. "+", ""):gsub(chars .. "+$", ""))
    end,
    strjoin = function(sep, ...) return table.concat({ ... }, sep) end,
    tostringall = function(...) local t = { n = select("#", ...), ... }; for i = 1, t.n do t[i] = tostring(t[i]) end; return unpack(t, 1, t.n) end,
    date = function(...) return osdate(...) end,
    debugstack = function() return debug.traceback("", 2) end,
    GetTimePreciseSec = function() return osclock() end,
    debugprofilestop = function() return osclock() * 1000 end,
    -- The game's trig functions work in degrees.
    sin = function(d) return math.sin(math.rad(d)) end, cos = function(d) return math.cos(math.rad(d)) end,
    tan = function(d) return math.tan(math.rad(d)) end, asin = function(x) return math.deg(math.asin(x)) end,
    acos = function(x) return math.deg(math.acos(x)) end, atan = function(x) return math.deg(math.atan(x)) end,
    atan2 = function(y, x) return math.deg(math.atan2(y, x)) end,
}
HELPERS.CreateFromMixins = function(...) return HELPERS.Mixin({}, ...) end

-- What the game's own Lua aliases are: strsub is string.sub, tinsert is table.insert, floor is math.floor, mod is math.fmod.
local function luaAlias(name)
    if HELPERS[name] then return HELPERS[name] end
    if name == "mod" then return math.fmod end
    if name == "strrev" then return string.reverse end
    if name == "getn" then return table.getn end
    for _, lib in ipairs({ string, table, math }) do if type(lib[name]) == "function" then return lib[name] end end
    local s = name:match("^str(%l+)$")
    if s and type(string[s]) == "function" then return string[s] end
    local t = name:match("^t(%l+)$")
    if t and type(table[t]) == "function" then return table[t] end
    return nil
end

-- Makes the global table look like the client's: every global function the client lacks becomes nil, every function the
-- client has that nothing set becomes a stub that returns nothing (st.generated names them), and the C_ namespaces get
-- the same treatment member by member. GetBuildInfo gives the client's real build. Lua's base functions and library
-- tables are left alone.
local LUA_BASE = {}
for n in ("assert collectgarbage dofile error gcinfo getfenv getmetatable ipairs load loadfile loadstring module newproxy next "
    .. "pairs pcall print rawequal rawget rawset require select setfenv setmetatable tonumber tostring type unpack xpcall"):gmatch("%S+") do
    LUA_BASE[n] = true
end
function H.applySurface(st, surface)
    st.generated = {}
    local function generic(name) st.generated[name] = true; return function() end end
    for k, v in pairs(_G) do -- also what an earlier fake client or load in this process left behind
        -- Lua's base functions stay unless the client lacks them too (dofile, load, loadfile, module, require).
        local base = LUA_BASE[k] and not surface.lacksBase[k]
        if type(k) == "string" and type(v) == "function" and not base and not surface.functions[k] then rawset(_G, k, nil) end
        if type(k) == "string" and type(v) == "table" and k:match("^C_") and not surface.namespaces[k] then rawset(_G, k, nil) end
    end
    for name in pairs(surface.functions) do
        if rawget(_G, name) == nil then rawset(_G, name, luaAlias(name) or generic(name)) end
    end
    for ns, members in pairs(surface.namespaces) do
        -- A new table: the one an earlier fake client made stays as it was, so H.snapshot can put it back.
        local old, t = rawget(_G, ns), {}
        if type(old) == "table" then for k, v in pairs(old) do if type(v) ~= "function" or members[k] then t[k] = v end end end
        for k in pairs(members) do if t[k] == nil then t[k] = generic(ns .. "." .. k) end end
        rawset(_G, ns, t)
    end
    -- A client on the processor path (surface.tooltipHooks) has TooltipDataProcessor; one on the script path has none (measured).
    if surface.tooltipHooks == "processor" then
        st.frames.postCalls = {}
        local enum = {} -- a new table: an Enum an earlier client made stays as it was, so H.snapshot can put it back
        for k, v in pairs(rawget(_G, "Enum") or {}) do enum[k] = v end
        enum.TooltipDataType = enum.TooltipDataType or { Item = 0 }
        rawset(_G, "Enum", enum)
        rawset(_G, "TooltipDataProcessor", {
            AddTooltipPostCall = function(kind, fn)
                if type(fn) ~= "function" then error("Usage: TooltipDataProcessor.AddTooltipPostCall(tooltipType, postCall)", 2) end
                local calls = st.frames.postCalls
                calls[#calls + 1] = { kind = kind == enum.TooltipDataType.Item and "item" or "other", fn = fn }
            end,
        })
    elseif surface.tooltipHooks == "script" then
        rawset(_G, "TooltipDataProcessor", nil)
    end
    -- The game's own tooltip, which records the lines an addon adds (H.tooltipLines).
    if surface.widgets.GameTooltip and rawget(_G, "GameTooltip") == nil then
        -- The game's tooltip has the methods of GameTooltipTemplate too (Forever generates SetHyperlink and the other Set* ones there).
        local template = surface.templates and surface.templates.GameTooltipTemplate and "GameTooltipTemplate" or nil
        _G.GameTooltip = stubFrame(st.frames, template, "GameTooltip", "GameTooltip")
    end
    local version, build = tostring(surface.build):match("^(%d+%.%d+%.%d+)%.(%d+)$")
    _G.GetBuildInfo = function() return version or surface.build, build or "", "", surface.interface end
end

-- A virtual clock (offline level 4). GetTime, time and C_Timer read it; st.advance(seconds) moves it on and runs each
-- timer that comes due, in the order the game would: by due time, then by the order they were made. A timer a callback
-- makes runs too when it comes due inside the same advance. clock.start is GetTime at the start (default 1) and
-- clock.epoch is what time() returns at GetTime 1. Returns nothing; st.now is the clock.
function H.clock(st, clock)
    clock = type(clock) == "table" and clock or {}
    local start = clock.start or 1
    local epoch = clock.epoch or 1764028800 -- 2025-11-25 00:00 UTC
    local ostime = os.time -- read now: the runner hides os from addon code
    st.now, st.queue, st.seq = start, {}, 0
    local function add(seconds, fn, handle, level)
        if type(seconds) ~= "number" or type(fn) ~= "function" then error("Usage: C_Timer(seconds, callback)", level) end
        st.seq = st.seq + 1
        st.queue[#st.queue + 1] = { due = st.now + math.max(seconds, 0), seq = st.seq, fn = fn, handle = handle, every = seconds }
    end
    local function handle(seconds, fn, iterations)
        if iterations ~= nil and type(iterations) ~= "number" then error("Usage: C_Timer.NewTicker(seconds, callback[, iterations])", 3) end
        local h = { cancelled = false, left = iterations }
        function h.Cancel(self) (self or h).cancelled = true end
        function h.IsCancelled(self) return (self or h).cancelled end
        add(seconds, fn, h, 4)
        return h
    end
    _G.GetTime = function() return st.now end
    _G.time = function(t) -- epoch at GetTime 1, also after a reload; time{year=...} as in the game
        if type(t) == "table" then return ostime(t) end
        return epoch + math.floor(st.now - 1)
    end
    _G.C_Timer = {
        After = function(seconds, fn) add(seconds, fn, nil, 3) end,
        NewTimer = function(seconds, fn) return handle(seconds, fn, 1) end,
        NewTicker = function(seconds, fn, iterations) return handle(seconds, fn, iterations) end,
    }
    st.timers = st.queue
    -- Returns the number of callbacks run, and the first error a callback raised (the others still run, as in the game).
    -- A wait stops after st.maxCallbacks callbacks with an error, so timers that keep making 0-second timers cannot hang it.
    st.maxCallbacks = 100000
    function st.advance(seconds)
        local target, ran, firstErr = st.now + math.max(seconds or 0, 0), 0, nil
        while true do
            local best, bi
            for i, t in ipairs(st.queue) do
                if t.due <= target and (not best or t.due < best.due or (t.due == best.due and t.seq < best.seq)) then best, bi = t, i end
            end
            if not best then break end
            if ran >= st.maxCallbacks then
                firstErr = firstErr or ("timers ran %d times in one wait: use a shorter wait, or look for a timer that keeps making 0-second timers"):format(ran)
                break
            end
            table.remove(st.queue, bi)
            local h = best.handle
            if not (h and h.cancelled) then
                st.now = math.max(st.now, best.due)
                ran = ran + 1
                local ok, err = H.budgeted(st.scriptBudget, best.fn, h)
                if not ok and not firstErr then firstErr = tostring(err) end
                if h and not h.cancelled then
                    if h.left then h.left = h.left - 1 end
                    if not h.left or h.left > 0 then
                        st.seq = st.seq + 1
                        best.due, best.seq = st.now + math.max(best.every, 0.0001), st.seq -- a 0-second ticker still moves on
                        st.queue[#st.queue + 1] = best
                    else
                        h.cancelled = true
                    end
                end
            end
        end
        st.now = target
        return ran, firstErr
    end
end

-- What a TOC says about saved variables: the names on its SavedVariables and SavedVariablesPerCharacter lines, in order,
-- and whether LoadSavedVariablesFirst is 1. Returns nil when the file cannot be read.
function H.tocMeta(toc)
    local f = io.open(toc, "r")
    if not f then return nil end
    local text = f:read("*a"); f:close()
    local meta, seen = { savedVariables = {}, savedVariablesFirst = false }, {}
    for l in (text .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
        local key, value = l:match("^%s*##%s*([%w]+)%s*:%s*(.-)%s*$")
        if key == "SavedVariables" or key == "SavedVariablesPerCharacter" then
            for n in value:gmatch("[^,%s]+") do
                if not seen[n] then seen[n] = true; meta.savedVariables[#meta.savedVariables + 1] = n end
            end
        elseif key == "LoadSavedVariablesFirst" then
            meta.savedVariablesFirst = value == "1"
        end
    end
    return meta
end

-- Takes a copy of the global table and of the standard library tables. restore() removes every key added since and
-- puts the old values back, so the next load starts as the first did: an addon's globals, LibStub and its libraries
-- are gone. It works in one Lua state, so a change elsewhere (such as a type's metatable) is not undone.
local LIBRARY_TABLES = { "string", "table", "math", "bit", "coroutine" }
function H.snapshot()
    local function copy(t) local c = {}; for k, v in next, t do c[k] = v end; return c end
    local g = copy(_G)
    local libs = {}
    for _, n in ipairs(LIBRARY_TABLES) do if type(g[n]) == "table" then libs[g[n]] = copy(g[n]) end end
    -- A LibStub loaded before the snapshot keeps its registry: copy the tables a library registers in as well.
    local stub = g.LibStub
    if type(stub) == "table" then
        libs[stub] = copy(stub)
        for _, n in ipairs({ "libs", "minors" }) do if type(stub[n]) == "table" then libs[stub[n]] = copy(stub[n]) end end
        -- A later load of a newer minor changes a registered library in place: keep each one's fields too.
        if type(stub.libs) == "table" then
            for _, lib in next, stub.libs do if type(lib) == "table" and not libs[lib] then libs[lib] = copy(lib) end end
        end
    end
    local function put(t, c)
        for k in next, copy(t) do if c[k] == nil then rawset(t, k, nil) end end
        for k, v in next, c do rawset(t, k, v) end
    end
    return function()
        put(_G, g)
        for t, c in pairs(libs) do put(t, c) end
    end
end

function H.loadToc(ns, toc)
    for _, path in ipairs(assert(H.tocFiles(toc))) do assert(loadfile(path))("CheckThat", ns) end
end

-- Undo list for the running test: H.stub and T.finally push here, test() unwinds it after the test, pass or fail.
local undo, running = {}, false

-- Sets t[key] = value and restores the old value (nil too) after the test, also when the test fails.
function H.stub(t, key, value)
    assert(running, "H.stub outside a test: it would be undone after the first test")
    local old = rawget(t, key)
    undo[#undo + 1] = function() rawset(t, key, old) end
    rawset(t, key, value)
end

-- Script-time budget (#155). The game stops an addon script that runs too long ("script ran too long"), which a plain pcall
-- never shows offline. H.budgeted(budget, fn, ...) is pcall with a count hook: an instruction costs 1 and a call 20, and the
-- call raises once the cost passes budget. No budget (nil or false) is a plain pcall. Measured in game (docs/contracts.md): a call
-- costs about 8 loop turns, so 20 units is near right; the game ran 1.2 billion units (3.5 s) without stopping a script, so its
-- limit is higher than that. H.DEFAULT_BUDGET is far below the game's limit: it stops a runaway loop offline, not a slow script. The offline runner uses it from level 5 on, and tests pass their own
-- budget to stubClient({ scriptBudget = n }) for timer callbacks. A coroutine the script starts has no hook, so its work is not counted.
H.DEFAULT_BUDGET = 100000000
local CALL_COST, COUNT_STEP = 20, 100
local budgetActive = false
local HARNESS_SRC = debug.getinfo(1, "S").short_src
function H.budgeted(budget, fn, ...)
    -- A nested call (a handler that fires another budgeted callback) is counted by the outer call, so it is a plain pcall.
    if not budget or not debug.sethook or budgetActive then return pcall(fn, ...) end
    local oldHook, oldMask, oldCount = debug.gethook()
    local jitWasOn = jit and jit.status and jit.status()
    if jit then jit.off() end -- compiled loops skip the hook
    local spent = 0
    budgetActive = true
    -- The hook stays on once it trips, so a script that catches the error with pcall and loops again is stopped again.
    -- It never raises in this file's own code or in a C function, so it cannot fire after fn returns, while the hook is
    -- being taken off: the error always lands inside the script.
    debug.sethook(function(ev)
        spent = spent + (ev == "count" and COUNT_STEP or CALL_COST)
        if spent > budget then
            local where = debug.getinfo(2, "S")
            if where and (where.short_src == HARNESS_SRC or where.what == "C") then return end
            error(("script ran too long: it used more than %d units of work (an instruction counts 1, a call 20); the game stops a script that runs too long"):format(budget), 0)
        end
    end, "c", COUNT_STEP)
    local function done(...)
        debug.sethook()
        if oldHook then debug.sethook(oldHook, oldMask, oldCount) end
        if jitWasOn then jit.on() end
        budgetActive = false
        return ...
    end
    return done(pcall(fn, ...))
end

-- Exit code of a file whose name filter matched no test; tests/run.lua reads it.
H.NO_MATCH = 3

-- A value as the failure message shows it: strings quoted, tables one level deep, so "nil" and nil differ.
local function fmt(v)
    local ty = type(v)
    if ty == "string" then return ("%q"):format(v) end
    if ty ~= "table" then return ty == "nil" and "nil" or ("%s %s"):format(ty, tostring(v)) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for i, k in ipairs(keys) do
        if i > 8 then parts[#parts + 1] = "..."; break end
        local x = v[k]
        parts[#parts + 1] = ("%s=%s"):format(tostring(k), type(x) == "table" and "{...}" or fmt(x))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- The first path where a and b differ, with both values, or nil when they are equal.
local function firstDiff(a, b, path)
    if type(a) ~= "table" or type(b) ~= "table" then
        if a == b then return nil end
        return path, a, b
    end
    local keys, seen = {}, {}
    for k in pairs(a) do keys[#keys + 1] = k; seen[k] = true end
    for k in pairs(b) do if not seen[k] then keys[#keys + 1] = k end end
    table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
    for _, k in ipairs(keys) do
        local p, x, y = firstDiff(a[k], b[k], path .. "." .. tostring(k))
        if p then return p, x, y end
    end
    return nil
end

return function()
    local ns = {}
    local T, fails, pass = {}, 0, 0
    function T.eq(a, b, msg)
        if a ~= b then error(("%s: expected %s, got %s"):format(msg or "eq", fmt(b), fmt(a)), 2) end
    end
    function T.ok(v, msg) if not v then error(msg or "expected truthy", 2) end end
    local function deepEq(a, b) return firstDiff(a, b, "") == nil end
    T.deepEq = deepEq
    -- Deep compare that names the first differing path.
    function T.same(a, b, msg)
        local path, x, y = firstDiff(a, b, "")
        if path then
            error(("%s: differs at %s: expected %s, got %s"):format(msg or "same", path == "" and "<root>" or path:sub(2), fmt(y), fmt(x)), 2)
        end
    end
    -- fn must raise, and the message must contain the plain text pattern.
    function T.raises(fn, pat, msg)
        local ok, err = pcall(fn)
        if ok then error((msg or "raises") .. ": expected an error, the call succeeded", 2) end
        if pat and not tostring(err):find(pat, 1, true) then
            error(("%s: expected an error containing %s, got %s"):format(msg or "raises", fmt(pat), fmt(tostring(err))), 2)
        end
    end
    function T.finally(fn)
        assert(running, "T.finally outside a test")
        undo[#undo + 1] = fn
    end
    local pattern = arg and arg[1]
    local function trace(e)
        local tb = debug.traceback(tostring(e), 2)
        return (tb:gsub("\n[^\n]*tests/harness%.lua[^\n]*", ""))
    end
    local function test(name, fn)
        if pattern and not name:find(pattern, 1, true) then return end
        running = true
        local ok, err = xpcall(fn, trace)
        running = false
        for i = #undo, 1, -1 do
            local uok, uerr = pcall(undo[i])
            if not uok then
                ok, err = false, (ok and "" or tostring(err) .. "\n") .. "cleanup failed: " .. tostring(uerr)
            end
            undo[i] = nil
        end
        if ok then pass = pass + 1 else fails = fails + 1; rawprint("FAIL " .. name .. ": " .. tostring(err)) end
    end
    local function finish()
        rawprint(("%d passed, %d failed"):format(pass, fails))
        if fails > 0 then os.exit(1) end
        os.exit((pattern and pass == 0) and H.NO_MATCH or 0)
    end
    ns.__plain = function() H.plain(ns) end
    return ns, test, T, finish, H
end
