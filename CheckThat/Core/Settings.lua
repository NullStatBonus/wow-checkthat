-- The public settings keys, shared by the settings window and /ct get|set so both validate the same way.
-- Plain Lua: the saved profile comes from ns.addon.db or the defaults, and Settings.onChange is set by the card.
local _, ns = ...
local L = ns.L

local Settings = { onChange = function() end }
ns.Settings = Settings

local function profile()
    return ns.addon and ns.addon.db and ns.addon.db.profile or ns.defaults.profile
end
Settings.profile = profile

-- key -> { field in profile.card, kind = "int" | "bool", min, max }
Settings.keys = {
    ["card.scale"] = { field = "scale", kind = "int", min = 50, max = 200 },
    ["card.background-opacity"] = { field = "backgroundOpacity", kind = "int", min = 0, max = 100 },
    ["card.text-opacity"] = { field = "textOpacity", kind = "int", min = 0, max = 100 },
    ["card.locked"] = { field = "locked", kind = "bool" },
    ["card.sound"] = { field = "sound", kind = "bool" },
}
Settings.order = { "card.scale", "card.background-opacity", "card.text-opacity", "card.locked", "card.sound" }

function Settings.Syntax(key)
    local k = Settings.keys[key]
    if not k then
        return L["Unknown key. Keys: card.scale (50-200), card.background-opacity (0-100), card.text-opacity (0-100), card.locked (on or off), card.sound (on or off)."]
    end
    if k.kind == "bool" then return L["%s accepts on or off."]:format(key) end
    return L["%s accepts a whole number from %d to %d."]:format(key, k.min, k.max)
end

function Settings.Get(key)
    local k = Settings.keys[key]
    if not k then return nil end
    return profile().card[k.field]
end

-- Value as shown to the player.
function Settings.Value(key)
    local v = Settings.Get(key)
    if type(v) == "boolean" then return v and "on" or "off" end
    return tostring(v)
end

-- Validates and stores. value is a string (command) or a number/boolean (settings window).
-- Returns ok, message. Nothing is written on a rejected value.
function Settings.Set(key, value)
    local k = Settings.keys[key]
    if not k then return false, Settings.Syntax(key) end
    local v
    if k.kind == "bool" then
        if value == true or value == "on" then v = true
        elseif value == false or value == "off" then v = false
        else return false, Settings.Syntax(key) end
    else
        local n = tonumber(value)
        if type(value) == "string" and not value:match("^%d+$") then n = nil end
        if not n or n ~= math.floor(n) or n < k.min or n > k.max then return false, Settings.Syntax(key) end
        v = n
    end
    profile().card[k.field] = v
    Settings.onChange()
    if ns.App and ns.App.Log then ns.App.Log(("setting %s = %s"):format(key, tostring(v))) end -- a plan can check a change from chat
    return true, L["%s = %s"]:format(key, Settings.Value(key))
end

function Settings.ResetPosition()
    profile().card.pos = nil
    Settings.onChange()
end

-- Every saved setting as "key = value" lines for the status command.
function Settings.Status()
    local out = {}
    for _, key in ipairs(Settings.order) do out[#out + 1] = L["%s = %s"]:format(key, Settings.Value(key)) end
    return out
end
