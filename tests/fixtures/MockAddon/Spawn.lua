-- Fixture: the first FOO handler creates a second frame that registers FOO. Not shipped.
local frame = CreateFrame("Frame")
frame:RegisterEvent("FOO")
frame:SetScript("OnEvent", function()
    if MockSpawned then return end
    MockSpawned = CreateFrame("Frame")
    MockSpawned:RegisterEvent("FOO")
    MockSpawned:SetScript("OnEvent", function() end)
end)
