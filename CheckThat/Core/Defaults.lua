-- Saved settings and their defaults. AceDB fills in missing keys, so a setting added later starts at its default.
-- profile: how the card looks and the debug switch (shared Default profile, or one per character).
-- global: plans, runs and the debug log (account-wide; never copied between profiles).
local _, ns = ...

ns.defaults = {
    profile = {
        debug = false,           -- record the debug log (Debug/Log.lua)
        card = {
            scale = 100,            -- percent, 50-200
            backgroundOpacity = 90, -- percent, 0-100; the fill is pure black
            textOpacity = 100,      -- percent, 0-100
            locked = false,         -- the card cannot be dragged
            collapsed = false,
            pos = nil,              -- { point, relativePoint, x, y }, set when the player moves the card
        },
    },
    global = {
        plans = {},              -- [addon] = { plan, digest }, the latest import per addon
        planStore = {},          -- [digest] = plan, so a run keeps the plan it started with
        runs = {},               -- [runId] = run (Model/Run.lua)
        runLimit = 20,           -- most runs kept, 5-100; the oldest go first, never a character's current run
        currentByChar = {},      -- ["Name-Realm"] = runId
        log = { entries = {} },  -- Debug/Log.lua: { t = time, msg = "[area] text" }
        ui = {},                 -- small flags: macro name/body, reload prompt
    },
}
