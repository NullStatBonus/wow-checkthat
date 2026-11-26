-- Fixture: the runner hides io from addon code and records the globals the addon folder read as nil.
local addonName = ...
ffi = "leak" -- the runner must not leave this in the host's globals
local sawIo = io ~= nil -- a guard at file scope: the game has no io
if CheckThat and CheckThat.Entry then
    CheckThat.Entry(addonName, "guard_io", function() return io == nil, sawIo end)
    CheckThat.Entry(addonName, "call_io", function() return io.open("x") end)
    CheckThat.Entry(addonName, "missing_api", function() return C_NotInThisClient ~= nil end)
end
