-- Every game API read lives here, guarded, returning nil when the function is missing. Model code never
-- calls the game directly: it gets Adapter.Env(), a table of the few reads it needs (plus read-only
-- access to other addons' saved globals, which is what the evidence checks read).
local _, ns = ...

local Adapter = {}
ns.Adapter = Adapter

local function call(name, ...)
    local f = _G[name]
    if type(f) ~= "function" then return nil end
    local r = { pcall(f, ...) }
    if r[1] then return unpack(r, 2) end
end

function Adapter.Env()
    local env = {}
    for _, name in ipairs({ "GetBuildInfo", "UnitName", "GetRealmName", "GetNormalizedRealmName", "UnitFullName", "time" }) do
        env[name] = function(...) return call(name, ...) end
    end
    env.IsAddOnLoaded = function(addon)
        local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        if type(f) ~= "function" then return nil end
        local ok, loaded = pcall(f, addon)
        if not ok then return nil end -- unknown, never "false": a missing answer must not satisfy an eq false check
        return loaded and true or false
    end
    return setmetatable(env, { __index = _G })
end

function Adapter.Now() return call("time") end

-- The addon's own version from the TOC ("unknown" when the client cannot say).
function Adapter.Version()
    local f = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(f) ~= "function" then return "unknown" end
    local ok, v = pcall(f, ns.name, "Version")
    return ok and type(v) == "string" and v ~= "" and v or "unknown"
end
ns.version = Adapter.Version()
-- Runs fn after sec seconds, if the client has timers.
function Adapter.After(sec, fn)
    if _G.C_Timer and _G.C_Timer.After then _G.C_Timer.After(sec, fn) end
end
function Adapter.InCombat() return call("InCombatLockdown") and true or false end
function Adapter.Reload() return call("ReloadUI") end
-- Hide a frame for the whole of combat, and show it again when combat ends (the owner re-checks it then).
function Adapter.HideInCombat(frame) return call("RegisterStateDriver", frame, "visibility", "[combat] hide; show") end

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

-- A native confirmation dialog. onAccept runs only on the player's click.
function Adapter.Confirm(text, onAccept)
    if not (_G.StaticPopupDialogs and _G.StaticPopup_Show) then return false end
    _G.StaticPopupDialogs["WOWCHECKTHAT_CONFIRM"] = {
        text = text, button1 = _G.YES or "Yes", button2 = _G.NO or "No", timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3, OnAccept = onAccept,
    }
    _G.StaticPopup_Show("WOWCHECKTHAT_CONFIRM")
    return true
end
