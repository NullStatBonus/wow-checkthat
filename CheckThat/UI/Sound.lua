-- Result sounds (#229): CheckThat's own short tones, so a tester who watches the game hears what a step got.
-- One sound per moment: cues asked for together collapse to the most important. Every sound played is logged.
local addonName, ns = ...
local A = ns.Adapter

local Sound = {}
ns.Sound = Sound

Sound.FILES = {
    tick = "tick.ogg",              -- the player recorded a result
    ["chime-up"] = "chime-up.ogg",  -- CheckThat recorded a pass
    ["chime-down"] = "chime-down.ogg", -- CheckThat recorded a fail
    attention = "attention.ogg",    -- unverified: the step needs the player
    finish = "finish.ogg",          -- the run's last result
}
Sound.NAMES = { "tick", "chime-up", "chime-down", "attention", "finish" }
Sound.CHANNEL = "SFX" -- the game's sound effects volume and mute apply

function Sound.Path(name)
    return ("Interface\\AddOns\\%s\\Media\\Sounds\\%s"):format(addonName or "CheckThat", Sound.FILES[name])
end

function Sound.Enabled()
    local p = ns.Settings and ns.Settings.profile and ns.Settings.profile()
    return not (p and p.card and p.card.sound == false)
end

local function play(name, stepId)
    local ok = A.PlaySoundFile(Sound.Path(name), Sound.CHANNEL)
    if ok and ns.App then ns.App.Log(("sound %s for %s"):format(name, tostring(stepId or "?"))) end
    return ok
end

-- Plays the sound of a result now. With the setting off nothing plays. Results arrive one at a time; the batch at run
-- start asks once, and the run's last result asks for finish in place of its own sound.
function Sound.Cue(name, stepId)
    if not Sound.FILES[name] or not Sound.Enabled() then return end
    play(name, stepId)
end

-- /ct sound <name>: plays one sound now, whatever the setting says.
function Sound.Preview(name)
    if not Sound.FILES[name] then return false end
    return play(name, "preview") and true or false
end

-- The sound for a recorded result: by is "player" or "auto"; complete is true when no open step remains.
function Sound.For(verdict, by, complete)
    if verdict == "unverified" then return "attention" end
    if complete then return "finish" end
    if by == "auto" then
        if verdict == "pass" then return "chime-up" end
        if verdict == "fail" then return "chime-down" end
        return nil
    end
    if verdict == "pass" or verdict == "partial" or verdict == "fail" or verdict == "skip" then return "tick" end
    return nil
end

-- Steps that passed when the run started play one chime for the batch.
if ns.App then
    ns.App.OnStartPasses = function(n, firstId) if n > 0 then Sound.Cue("chime-up", firstId) end end
end
