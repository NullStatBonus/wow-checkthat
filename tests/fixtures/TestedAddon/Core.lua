-- Fixture for ct test: an addon a developer's own tests reach through its namespace. Not shipped.
local name, ns = ...
ns.name = name
ns.count = 0
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("PLAYER_LOGIN") -- CheckThat may set its global during its own ADDON_LOADED, after this frame got it
-- CheckThat integration, as a sibling addon writes it: CheckThat may load before this addon, after it, or not at all.
ns.ct = { api = "none", events = {} }
local function hookCheckThat()
    local CT = CheckThat
    if not CT or ns.ct.hooked then return end
    ns.ct.hooked = true
    if not CT.OnRun then ns.ct.api = "too old"; return end
    ns.ct.api = CT.API_VERSION
    CT.Entry(name, "count", function() return ns.count end)
    CT.Entry(name, "fail", function() error("entry broke") end)
    ns.ct.commands = CT.Commands(name, { "/tested" })
    CT.OnRun(name, function(event, info)
        ns.ct.events[#ns.ct.events + 1] = event .. ":" .. tostring(info.reason or info.plan)
        if info.plan == "Broken" then error("callback broke") end
        ns.testMode = event == "start" or nil
        CT.Report(name, "mode", ns.testMode and "test" or "player")
    end)
    ns.ct.active = CT.ActiveRun(name)
end
hookCheckThat()
f:SetScript("OnEvent", function(_, ev, arg)
    if (ev == "ADDON_LOADED" and arg == "CheckThat") or ev == "PLAYER_LOGIN" then
        hookCheckThat()
    elseif ev == "ADDON_LOADED" and arg == name then
        TestedAddonDB = TestedAddonDB or { runs = 0 }
        TestedAddonDB.runs = TestedAddonDB.runs + 1
        ns.runs = TestedAddonDB.runs
    elseif ev == "BAG_UPDATE" then
        ns.count = ns.count + 1
    end
end)
function ns.Money() return GetMoney() end
function ns.Sell()
    if InCombatLockdown() then error("in combat") end
    return true
end
