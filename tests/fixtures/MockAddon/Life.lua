-- Fixture addon for offline level 3: saved variables, login events and reload. Not shipped.
local addonName = ...
local dbAtLoad = MockLifeDB -- nil while the files run, unless the TOC loads saved variables first
MockLifeDB = { from = "file" } -- a file-scope default: a saved value replaces it at load
MockLifeLoose = (MockLifeLoose or 0) + 1 -- a global the TOC does not save: a reload starts it again
local upvalue = 0
local seen = {}

local frame = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" }) do frame:RegisterEvent(e) end
frame:SetScript("OnEvent", function(_, event, a, b)
    seen[#seen + 1] = table.concat({ event, tostring(a), tostring(b), tostring(IsLoggedIn()) }, " ")
    if event == "ADDON_LOADED" and a == addonName then
        frame:UnregisterEvent("ADDON_LOADED")
        MockLifeChar = MockLifeChar or { logins = 0 }
        MockLifeChar.logins = MockLifeChar.logins + 1
    elseif event == "PLAYER_LOGOUT" then
        MockLifeDB.logout = (MockLifeDB.logout or 0) + 1
    end
end)

CheckThat.Entry(addonName, "db", function() return MockLifeDB.from end)
CheckThat.Entry(addonName, "logouts", function() return MockLifeDB.logout end)
CheckThat.Entry(addonName, "set", function(v) MockLifeDB.from = v; upvalue = upvalue + 1; return upvalue end)
CheckThat.Entry(addonName, "db_at_load", function() return dbAtLoad and dbAtLoad.from or "nil" end)
CheckThat.Entry(addonName, "upvalue", function() return upvalue end)
CheckThat.Entry(addonName, "loose", function() return MockLifeLoose end)
CheckThat.Entry(addonName, "seen", function() return table.concat(seen, "; ") end)
CheckThat.Entry(addonName, "logins", function() return MockLifeChar and MockLifeChar.logins end)
CheckThat.Entry(addonName, "item", function() return (GetItemInfo(1)) end)
CheckThat.Entry(addonName, "flag", function(v) if v then MockLifeFlag = v end; return MockLifeFlag or "none" end)
-- What the game does not keep: a shared table comes back as two, a cycle and a function are dropped.
CheckThat.Entry(addonName, "shape", function()
    local t = { 1 }
    MockLifeDB.a, MockLifeDB.b, MockLifeDB.self, MockLifeDB.fn = t, t, MockLifeDB, print
    MockLifeDB.sparse = { [3] = "x" }
    return MockLifeDB.a == MockLifeDB.b
end)
CheckThat.Entry(addonName, "shape_after", function()
    local db = MockLifeDB
    return db.a ~= db.b and db.a[1] == 1, db.self == nil, db.fn == nil, type(next(db.sparse)) == "number"
end)
