-- Every game API read lives here, guarded, returning nil when the function is missing. Model code never
-- calls the game directly: it gets Adapter.Env(), a table of the few reads it needs (plus read-only
-- access to other addons' saved globals, which is what the evidence checks read).
local _, ns = ...

local Adapter = {}
ns.Adapter = Adapter

-- A value the game hides (a secret value) reads as nil: a probe never guesses (#67).
local function secret(v)
    local f = _G.issecretvalue
    if type(f) ~= "function" then return false end
    local ok, s = pcall(f, v)
    return ok and s and true or false
end

local function call(name, ...)
    local f = _G[name]
    if type(f) ~= "function" then return nil end
    local r = { pcall(f, ...) }
    if r[1] then
        if secret(r[2]) then return nil end
        return unpack(r, 2)
    end
end

-- A read on a client table (C_Item.GetItemCount), or the older global of the same name when the table or its function
-- is not there. The first spelling that has the function answers, also with nil. Missing, raising and secret reads are nil.
local function callName(space, name, ...)
    local t = _G[space]
    local f = type(t) == "table" and t[name] or nil
    if type(f) ~= "function" then return call(name, ...) end
    local r = { pcall(f, ...) }
    if r[1] then
        if secret(r[2]) then return nil end
        return unpack(r, 2)
    end
end

function Adapter.Env()
    local env = {}
    for _, name in ipairs({ "GetBuildInfo", "UnitName", "GetRealmName", "GetNormalizedRealmName", "UnitFullName", "time", "date", "GetMoney" }) do
        env[name] = function(...) return call(name, ...) end
    end
    -- Reads for the state probes (#67). Model asks for these names, so the client's spelling of each function stays here.
    env.ContainerFreeSlots = function(bag) return callName("C_Container", "GetContainerNumFreeSlots", bag) end
    env.ItemCount = function(id) return callName("C_Item", "GetItemCount", id) end
    -- What a named frame says: nil for a missing frame, one with no GetText, a raising read, a hidden (secret) value or one that is not text.
    env.FrameText = function(name)
        local ok, t = pcall(function()
            local f = type(name) == "string" and _G[name] or nil
            if type(f) ~= "table" or type(f.GetText) ~= "function" then return nil end
            local v = f:GetText()
            if secret(v) or type(v) ~= "string" then return nil end
            return v
        end)
        return ok and t or nil
    end
    -- Missing or failing reads as in combat: nothing may run when the game cannot say.
    env.InCombatLockdown = function()
        local f = _G.InCombatLockdown
        if type(f) ~= "function" then return true end
        local ok, r = pcall(f)
        if not ok then return true end
        return r and true or false
    end
    env.IsAddOnLoaded = function(addon)
        local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        if type(f) ~= "function" then return nil end
        local ok, loaded = pcall(f, addon)
        if not ok then return nil end -- unknown, never "false": a missing answer must not satisfy an eq false check
        return loaded and true or false
    end
    -- Reads for the client census (Model/Census.lua); the functions are below.
    for _, name in ipairs({ "After", "Clock", "CensusNextKey", "CensusType", "CensusOpen", "CensusMember", "CensusWidget", "CensusWidgetKinds", "LoadedAddons", "SlashOwner" }) do
        env[name] = function(...) return Adapter[name](...) end
    end
    return setmetatable(env, { __index = _G })
end

-- Publishes a table as a game global, for the one public API other addons call.
function Adapter.Export(name, value) return (pcall(rawset, _G, name, value)) end

function Adapter.Now() return call("time") end

-- The addon's own version from the TOC ("unknown" when the client cannot say).
function Adapter.Version()
    local f = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(f) ~= "function" then return "unknown" end
    local ok, v = pcall(f, ns.name, "Version")
    return ok and type(v) == "string" and v ~= "" and v or "unknown"
end
ns.version = Adapter.Version()
-- The TOC version of another addon (the one under test), or nil when it is not installed, has no version or the client cannot say.
function Adapter.AddonVersion(name)
    if type(name) ~= "string" or name == "" then return nil end
    local f = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, name, "Version")
    if ok and type(v) == "string" and v ~= "" and v ~= "unknown" then return v end
    return nil
end
-- The player's class token (MAGE, HUNTER...), or nil when the game cannot say. env is the game, or a fake in tests.
function Adapter.ClassToken(env)
    env = env or _G
    local f = env.UnitClass
    if type(f) ~= "function" then return nil end
    local ok, _, token = pcall(f, "player")
    return ok and type(token) == "string" and token ~= "" and token or nil
end
-- The names of the professions the player knows, as a set, or nil when the game cannot say. A client with
-- GetProfessions lists only professions; an older one lists every skill line that is not a header.
function Adapter.Professions(env)
    env = env or _G
    local names = {}
    if type(env.GetProfessions) == "function" and type(env.GetProfessionInfo) == "function" then
        local got = { pcall(env.GetProfessions) }
        if not got[1] then return nil end
        for i = 2, 7 do
            local ix = got[i]
            if ix ~= nil then
                local ok, name = pcall(env.GetProfessionInfo, ix)
                if ok and type(name) == "string" then names[name] = true else return nil end
            end
        end
        return names
    end
    if type(env.GetNumSkillLines) == "function" and type(env.GetSkillLineInfo) == "function" then
        local ok, n = pcall(env.GetNumSkillLines)
        if not ok or type(n) ~= "number" or n == 0 then return nil end -- no lines yet (before the skill data loads)
        for i = 1, n do
            local ok2, name, header, expanded = pcall(env.GetSkillLineInfo, i)
            if ok2 and header and not expanded then return nil end -- a collapsed header hides its lines: unknown, not missing
            if ok2 and type(name) == "string" and not header then names[name] = true end
        end
        return names
    end
    return nil
end
-- Runs fn after sec seconds. Returns true when it is scheduled, false when the client has no timers or refuses.
function Adapter.After(sec, fn)
    local f = _G.C_Timer and _G.C_Timer.After
    if type(f) ~= "function" then return false end
    return (pcall(f, sec, fn))
end
-- Plays a sound file on a sound channel (#229). True when the game accepted it, nil when it cannot play files.
function Adapter.PlaySoundFile(path, channel)
    local f = _G.PlaySoundFile
    if type(f) ~= "function" then return nil end
    local ok, willPlay = pcall(f, path, channel)
    if not ok then return nil end
    return willPlay ~= false
end
-- Milliseconds from the profiling clock, or nil when the client has none.
function Adapter.Clock()
    local ok, v = pcall(function() return _G.debugprofilestop() end)
    return ok and type(v) == "number" and v or nil
end
-- The census reads globals with rawget and next, so no __index or __newindex of a game table runs.
-- One step through _G: the key after cursor (nil starts, and nil comes back at the end), as ok, key. ok is false
-- when next fails (the table changed under the walk). The caller keeps the cursor between frames.
function Adapter.CensusNextKey(cursor)
    local ok, k = pcall(next, _G, cursor)
    if ok then return true, k end
    return false
end
-- Who registered a slash command (#244): the addon that wrote the SLASH_<KEY><n> global whose value is cmd, "game" when the game
-- defined it, or nil when no registered command has that text or the client cannot say. issecurevariable names the addon that
-- last wrote a global (measured on both clients, docs/contracts.md).
-- The second value says how it was decided, for the debug log: the SLASH_ global and its owner, or why there is none.
function Adapter.SlashOwner(cmd)
    if type(cmd) ~= "string" then return nil, "not text" end
    local list, check = _G.SlashCmdList, _G.issecurevariable
    if type(list) ~= "table" then return nil, "no SlashCmdList" end
    if type(check) ~= "function" then return nil, "no issecurevariable" end
    cmd = cmd:lower()
    local keys = {}
    local okKeys = pcall(function() for key in pairs(list) do keys[#keys + 1] = key end end)
    if not okKeys then return nil, "SlashCmdList cannot be listed" end
    local found
    for _, key in ipairs(keys) do
        -- One key at a time: a key that cannot be read skips itself, never the rest.
        local ok, name = pcall(function()
            if type(key) ~= "string" then return nil end
            for n = 1, 20 do
                local g = "SLASH_" .. key .. n
                local v = _G[g]
                if v == nil then return nil end
                if type(v) == "string" and v:lower() == cmd then return g end
            end
        end)
        if ok and name then found = name; break end
    end
    if not found then return nil, ("no SLASH_ global holds it (%d keys)"):format(#keys) end
    local ok2, secure, by = pcall(check, found)
    if not ok2 then return nil, found .. ": issecurevariable failed" end
    if secure then return "game", found .. " secure" end
    if type(by) == "string" and by ~= "" then return by, found .. " by " .. by end
    return nil, found .. " insecure, owner not named"
end
-- The Lua type of one global, or nil when it is gone. The second value is false for a name an addon defined
-- (issecurevariable), true for one the game defined, and nil when the client cannot tell.
function Adapter.CensusType(name)
    local ok, v = pcall(rawget, _G, name)
    if not ok or v == nil then return nil end
    local secure
    if type(_G.issecurevariable) == "function" then
        local ok2, s = pcall(_G.issecurevariable, name)
        if ok2 and type(s) == "boolean" then secure = s end
    end
    return type(v), secure
end
-- The member check of a table: issecurevariable(table, key), when this client accepts a table; nil when it does not.
local function memberCheck()
    local f = _G.issecurevariable
    if type(f) ~= "function" then return nil end
    local ok, r = pcall(f, {}, "x")
    if not ok or type(r) ~= "boolean" then return nil end
    return function(t, k)
        local ok2, s = pcall(f, t, k)
        if ok2 and type(s) == "boolean" then return s end
        return nil
    end
end
-- Opens a table global for member reads: a handle, whether it is a frame (its [0] is the userdata) and whether addon
-- members can be told apart. The handle is nil when the global is not a table or cannot be read, or is a frame.
function Adapter.CensusOpen(name)
    local ok, t = pcall(rawget, _G, name)
    if not ok or type(t) ~= "table" then return nil end
    local okz, zero = pcall(rawget, t, 0)
    if okz and type(zero) == "userdata" then return nil, true end
    local check = memberCheck()
    return { t = t, check = check }, false, check ~= nil
end
-- One member of an opened table: the key after cursor, as ok, key, type, keep, unknown. ok is false when next fails;
-- key is nil at the end. keep is false for a member an addon added. unknown is true when the member check gave no
-- answer for this key (the member is kept). Only next touches the table, so no __index runs.
function Adapter.CensusMember(h, cursor)
    local ok, k, v = pcall(next, h.t, cursor)
    if not ok then return false end
    if k == nil then return true end
    if not h.check then return true, k, type(v), true, false end
    local s = h.check(h.t, k)
    return true, k, type(v), s ~= false, s == nil
end
-- The widget types the census samples.
function Adapter.CensusWidgetKinds()
    return { "Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown", "Model", "MessageFrame",
        "ScrollingMessageFrame", "SimpleHTML", "ColorSelect", "GameTooltip", "FontString", "Texture" }
end
-- Hidden sample frames with no name, kept for the session: a frame cannot be freed.
local samples
-- The sorted method names on the metatable of a sample widget, or nil when CreateFrame refuses the type.
function Adapter.CensusWidget(kind)
    samples = samples or {}
    local ok, obj = pcall(function()
        if samples[kind] then return samples[kind] end
        local made
        if kind == "FontString" or kind == "Texture" then
            samples.Frame = samples.Frame or _G.CreateFrame("Frame", nil, _G.UIParent)
            made = kind == "FontString" and samples.Frame:CreateFontString() or samples.Frame:CreateTexture()
        else
            made = _G.CreateFrame(kind, nil, _G.UIParent)
            made:Hide()
        end
        samples[kind] = made
        return made
    end)
    if not ok or type(obj) ~= "table" then return nil end
    local methods
    ok = pcall(function()
        local index = getmetatable(obj).__index
        if type(index) ~= "table" then return end
        methods = {}
        for k, v in next, index do if type(k) == "string" and type(v) == "function" then methods[#methods + 1] = k end end
    end)
    return ok and methods or nil
end
-- The folder names of the loaded addons, or nil when the client cannot list them.
function Adapter.LoadedAddons()
    local ns_ = _G.C_AddOns or {}
    local count, info, loaded = ns_.GetNumAddOns or _G.GetNumAddOns, ns_.GetAddOnInfo or _G.GetAddOnInfo, ns_.IsAddOnLoaded or _G.IsAddOnLoaded
    if type(count) ~= "function" or type(info) ~= "function" or type(loaded) ~= "function" then return nil end
    local names = {}
    local ok = pcall(function()
        for i = 1, count() do
            local name = info(i)
            if type(name) == "table" then name = name.name end -- newer clients answer with a table
            if type(name) == "string" and loaded(name) then names[#names + 1] = name end
        end
    end)
    if ok then table.sort(names); return names end
end
-- The error handler is one slot shared by every addon. HookErrors sets ours over the current one (make(previous)
-- builds it) and does nothing when ours is still the current handler. Some addons take the slot and turn
-- seterrorhandler into a no-op (BugGrabber does: docs/contracts.md), so the call is checked by reading the
-- handler back. Returns true when ours is set. Returns nil when the client has no handler functions, and nil and
-- "blocked" when the set had no effect.
local oursHandler, blocked
function Adapter.HookErrors(make)
    local get, set = _G.geterrorhandler, _G.seterrorhandler
    if type(get) ~= "function" or type(set) ~= "function" then return nil end
    local ok, current = pcall(get)
    if not ok then return nil end
    if oursHandler ~= nil and current == oursHandler then return true end
    local built = make(current)
    if not (pcall(set, built)) then return nil end
    local ok2, now = pcall(get)
    if not ok2 or now ~= built then oursHandler, blocked = nil, true; return nil, "blocked" end
    oursHandler, blocked = built, false
    return true
end
-- Passes a message to the current error handler, as the game does for a Lua error. For the self-test only. Returns
-- false when the client has no handler.
function Adapter.RaiseTestError(msg)
    local get = _G.geterrorhandler
    if type(get) ~= "function" then return false end
    local ok, handler = pcall(get)
    if not ok or type(handler) ~= "function" then return false end
    pcall(handler, msg)
    return true
end
-- "current" when ours is the handler now, "replaced" when another addon set one after us, "blocked" when the set had no
-- effect, "off" before the hook or where the client has no handler functions.
function Adapter.ErrorHookState()
    local get = _G.geterrorhandler
    if type(get) ~= "function" then return "off" end
    local ok, current = pcall(get)
    if not ok then return "off" end
    if oursHandler ~= nil then return current == oursHandler and "current" or "replaced" end
    return blocked and "blocked" or "off"
end
-- The call stack as one string (debugstack), without the frames of the handler. Locals are never read. nil when the
-- client has no debugstack or it raises.
function Adapter.Stack()
    local f = _G.debugstack
    if type(f) ~= "function" then return nil end
    local ok, s = pcall(f, 4, 20, 0)
    return ok and type(s) == "string" and s or nil
end
-- Esc closes a named frame listed in UISpecialFrames. Registered once.
function Adapter.SpecialFrame(name)
    local list = _G.UISpecialFrames
    if type(list) ~= "table" then return false end
    for _, v in ipairs(list) do if v == name then return true end end
    list[#list + 1] = name
    return true
end
-- Missing or failing reads as in combat, like Adapter.Env: a protected frame must not be changed when the game cannot say.
function Adapter.InCombat()
    local f = _G.InCombatLockdown
    if type(f) ~= "function" then return true end
    local ok, r = pcall(f)
    if not ok then return true end
    return r and true or false
end
function Adapter.Reload() return call("ReloadUI") end
-- Hide a frame for the whole of combat, and show it again when combat ends (the owner re-checks it then).
function Adapter.HideInCombat(frame) return call("RegisterStateDriver", frame, "visibility", "[combat] hide; show") end
-- The driver shows its frame again every 0.2 seconds, so release a frame that must stay hidden. Out of combat only.
function Adapter.ReleaseCombatHide(frame) return call("UnregisterStateDriver", frame, "visibility") end

-- Macros the player can click. Never used in combat (callers check InCombat first).
function Adapter.MacroIndex(name) return call("GetMacroIndexByName", name) or 0 end
function Adapter.MacroBody(index)
    local _, _, body = call("GetMacroInfo", index)
    return body
end
function Adapter.EditMacro(index, name, body) return call("EditMacro", index, name, nil, body) end
function Adapter.CreateMacro(name, body)
    local f = _G.CreateMacro
    if type(f) ~= "function" then return false end
    return (pcall(f, name, "INV_Misc_QuestionMark", body, false))
end

-- Close the game's own Settings window before opening ours.
function Adapter.CloseGameSettings()
    if _G.SettingsPanel and _G.HideUIPanel then pcall(_G.HideUIPanel, _G.SettingsPanel)
    elseif _G.InterfaceOptionsFrame and _G.InterfaceOptionsFrame.Hide then pcall(_G.InterfaceOptionsFrame.Hide, _G.InterfaceOptionsFrame) end
end

-- A context menu at the cursor. items = { { text, onClick }, ... }. Returns false when the game has no menu API,
-- so the caller can fall back to a plain action. Newer clients have MenuUtil; older ones have UIDropDownMenu.
function Adapter.ContextMenu(owner, items)
    if _G.MenuUtil and _G.MenuUtil.CreateContextMenu then
        -- A menu that raises is not the end: the older dropdown may still work.
        if pcall(_G.MenuUtil.CreateContextMenu, owner, function(_, root)
            for _, it in ipairs(items) do root:CreateButton(it[1], it[2]) end
        end) then return true end
    end
    local g = _G
    if g.UIDropDownMenu_Initialize and g.ToggleDropDownMenu and g.UIDropDownMenu_CreateInfo and g.CreateFrame and g.UIParent then
        return (pcall(function()
            g.CheckThatMenu = g.CheckThatMenu or g.CreateFrame("Frame", "CheckThatMenu", g.UIParent, "UIDropDownMenuTemplate")
            g.UIDropDownMenu_Initialize(g.CheckThatMenu, function()
                for _, it in ipairs(items) do
                    local info = g.UIDropDownMenu_CreateInfo()
                    info.text, info.func, info.notCheckable = it[1], it[2], true
                    g.UIDropDownMenu_AddButton(info)
                end
            end, "MENU")
            g.ToggleDropDownMenu(1, nil, g.CheckThatMenu, "cursor", 0, 0)
        end))
    end
    return false
end

-- A tooltip with the given text next to owner. Returns false when the game has no tooltip.
function Adapter.Tooltip(owner, text)
    local tip = _G.GameTooltip
    if not (tip and tip.SetOwner and tip.SetText and text) then return false end
    return (pcall(function() tip:SetOwner(owner, "ANCHOR_BOTTOM"); tip:SetText(text, 1, 1, 1, 1, true); tip:Show() end))
end

function Adapter.TooltipHide()
    local tip = _G.GameTooltip
    if tip and tip.Hide then pcall(tip.Hide, tip) end
end

-- A native confirmation dialog. onAccept runs only on the player's click.
function Adapter.Confirm(text, onAccept)
    if not (_G.StaticPopupDialogs and _G.StaticPopup_Show) then return false end
    if type(_G.StaticPopup_Hide) == "function" then pcall(_G.StaticPopup_Hide, "WOWCHECKTHAT_CONFIRM") end -- an open one would keep its old text
    _G.StaticPopupDialogs["WOWCHECKTHAT_CONFIRM"] = {
        text = text, button1 = _G.YES or "Yes", button2 = _G.NO or "No", timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3, OnAccept = onAccept,
    }
    _G.StaticPopup_Show("WOWCHECKTHAT_CONFIRM")
    return true
end
