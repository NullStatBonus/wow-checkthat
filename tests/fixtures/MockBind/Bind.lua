-- Fixture: records ADDON_LOADED's values. Not shipped.
local addonName = ...
local got = "none"
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("ADDONS_UNLOADING")
f:SetScript("OnEvent", function(_, event, a, b)
    if event == "ADDON_LOADED" then got = tostring(a) .. " " .. tostring(b) else MockBindUnloading = tostring(a) end
end)
CheckThat.Entry(addonName, "loaded", function() return got, tostring(MockBindUnloading) end)
