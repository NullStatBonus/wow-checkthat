-- Fixture: records every lifecycle event it gets, with its arguments, in a saved variable. Not shipped.
local addonName = ...
MockOrderDB = MockOrderDB or { log = {} }
local frame = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "VARIABLES_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
    "PLAYER_LEAVING_WORLD", "ADDONS_UNLOADING", "PLAYER_LOGOUT" }) do frame:RegisterEvent(e) end
frame:SetScript("OnEvent", function(_, e, ...)
    local a = {}
    for i = 1, select("#", ...) do a[i] = tostring((select(i, ...))) end
    if e ~= "ADDON_LOADED" or (...) == addonName then MockOrderDB.log[#MockOrderDB.log + 1] = e .. "(" .. table.concat(a, ",") .. ")" end
end)
CheckThat.Entry(addonName, "order", function() return table.concat(MockOrderDB.log, " ") end)
