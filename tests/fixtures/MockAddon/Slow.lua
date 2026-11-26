-- Fixture: BAG_UPDATE makes this many reads in one handler (the bag id is the count). Not shipped.
local frame = CreateFrame("Frame")
frame:RegisterEvent("BAG_UPDATE")
local function reads(n) for i = 1, n do math.floor(i / 2) end end
frame:SetScript("OnEvent", function(_, _, n) reads(n) end)
