local addonName, ns = ...
local L = ns.L

local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")
ns.addon = addon

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("CheckThatDB", ns.defaults, true)
    ns.LibDeflate = LibStub("LibDeflate")
    ns.App.Init(self.db.global, ns.Adapter.Env(), { debug = function() return self.db.profile.debug end })
    ns.Adapter.Export("CheckThat", ns.Facts.API())
    ns.Errors.Hook()
    ns.Census.Init(self.db.global, ns.Adapter.Env())
    ns.Slash.Register(self)
    -- Feature modules register a starter in ns.starters (UI/Card.lua, Options/Options.lua).
    for _, start in ipairs(ns.starters or {}) do
        local ok, err = pcall(start, self)
        if not ok and ns.Log then ns.Log.Failure("start", err) end
    end
end

-- Registers only events the client has: registering a removed event raises a Lua error.
function ns.Listen(target, event, fn)
    return (pcall(target.RegisterEvent, target, event, fn))
end

function addon:OnEnable()
    -- A run from before a reload resumes: the open attempt asks for verification, not another reload.
    -- Only the character's open run resumes. The card may show an ended run from Past runs instead.
    local run = ns.App.OpenRecord()
    if run then
        ns.Errors.Rebase()
        ns.App.MarkReloaded()
        ns.App.Log("resumed run " .. run.runId .. " after load")
        if ns.Card then ns.Card.Show() end
        ns.Slash.Print(L["Reloaded. Your run continues on the same step."])
        ns.Slash.Print(ns.App.Status(run))
    end
    local newer = ns.App.FutureCount()
    if newer > 0 then
        ns.App.Log(("%d saved run(s) need a newer CheckThat; kept untouched"):format(newer))
        ns.Slash.Print(newer == 1 and L["One saved run needs a newer CheckThat. It is kept as it is."]
            or L["%d saved runs need a newer CheckThat. They are kept as they are."]:format(newer))
    end
    -- Off by default. A few seconds after login, outside combat, call the entries imported plans name and say how many matched.
    if self.db.profile.loginCheck then
        ns.Adapter.After(3, function()
            -- The timer fires later: look again at the setting, a run and combat.
            if not self.db.profile.loginCheck then return end
            if ns.App.RunOpen() then ns.App.Log("self-check skipped: a run is open"); return end
            if ns.Adapter.InCombat() then ns.App.Log("self-check skipped: in combat"); return end
            local total, matched, miss = ns.App.SelfCheck()
            if total == 0 then return end
            if miss then
                ns.Slash.Print(L["Self-check: %d of %d entry checks matched. First miss: %s"]:format(matched, total, (miss:gsub("|", "||"))))
            else
                ns.Slash.Print(L["Self-check: %d of %d entry checks matched."]:format(matched, total))
            end
        end)
    end
    ns.Listen(self, "PLAYER_REGEN_ENABLED", function() ns.Census.Resume(); if ns.Card then ns.Card.Refresh() end end)
    ns.Listen(self, "PLAYER_LOGOUT", function() ns.App.Log("logout"); if ns.Tracker then ns.Tracker.Leaving() end end)
end

-- Feature files call ns.Start(fn) at load; fn(addon) runs once saved settings are ready.
function ns.Start(fn)
    ns.starters = ns.starters or {}
    ns.starters[#ns.starters + 1] = fn
end
