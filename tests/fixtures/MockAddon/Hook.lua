-- Fixture: state a hook reads and changes through the addon's namespace (ctx.ns). Not shipped.
local _, ns = ...
ns.count = 0
ns.io = type(io) -- addon code does not see io
local f = CreateFrame("Frame")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function() ns.count = ns.count + 1; ns.handlerIo = type(io); ns.ffiSeen = ffi and ffi.mine end)
function ns.later() C_Timer.After(1, function() ns.inCombat = InCombatLockdown() end) end
function ns.laterLibs() C_Timer.After(1, function() ns.timerOs = type(os) end) end
ffi = { mine = true } -- an addon may use a hidden name for its own global
