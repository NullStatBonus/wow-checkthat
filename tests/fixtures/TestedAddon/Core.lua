-- Fixture for ct test: an addon a developer's own tests reach through its namespace. Not shipped.
local name, ns = ...
ns.name = name
ns.count = 0
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function(_, ev, arg)
    if ev == "ADDON_LOADED" and arg == name then
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
