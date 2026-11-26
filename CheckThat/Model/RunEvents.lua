-- Run start and end events for sibling addons, registered through CheckThat.OnRun (issue 171). An addon learns when
-- a run of a plan that names it becomes the open run or stops being it, so it can set up and restore its own test
-- state. Data only: the addon's own function is called in pcall, after the run state is saved, with a fresh copy of
-- the info table. Nothing here changes a run.
local _, ns = ...
local RunEvents = { NAME = 32 }
ns.RunEvents = RunEvents

local registry = {} -- addon -> fn
local openRun = function() return nil end

-- open() returns the open run of the current character, or nil.
function RunEvents.Bind(open)
    openRun = open or openRun
end

local function note(msg) if ns.Log then ns.Log.Record("runevents", msg) end end

local function validName(addon)
    return type(addon) == "string" and #addon >= 1 and #addon <= RunEvents.NAME and not addon:find("[^%w_%-]")
end

local function info(run, reason)
    return { plan = run.planTitle, digest = run.planDigest, runId = run.runId, reason = reason }
end

-- Calls the addon's function for this run. A raised error goes to the debug log and, while a run is open, to the
-- error list. Never raises.
function RunEvents.Notify(event, run, reason)
    local fn = run and registry[run.addon]
    if not fn then return false end
    local ok, err = pcall(fn, event, info(run, reason))
    note(("%s %s %s%s"):format(ok and "called" or "failed", run.addon, event, reason and (" " .. reason) or ""))
    if not ok then
        if ns.Errors then pcall(ns.Errors.Record, "run callback: " .. tostring(err), nil, run.addon) end
        note(("callback error %s: %s"):format(run.addon, tostring(err):gsub("%c+", " "):sub(1, 100)))
    end
    return ok
end

-- A change of the open run: the old one ends, the new one starts. Called after the state is saved.
function RunEvents.Changed(before, after, reason)
    if before == after then return end
    if before then RunEvents.Notify("end", before, reason) end
    if after then RunEvents.Notify("start", after) end
end

-- Returns true when fn is stored. A second registration for an addon replaces the first. A run that is already
-- open (a run survives /reload, and CheckThat loads before the addons) gets one "start" now.
function RunEvents.Register(addon, fn)
    if not validName(addon) or type(fn) ~= "function" then
        note("refused a run callback: the name or function is not valid"); return false
    end
    registry[addon] = fn
    note("registered run callback " .. addon)
    local run = openRun()
    if run and run.addon == addon then RunEvents.Notify("start", run) end
    return true
end

-- The plan title of the open run when its plan names the addon, else nil.
function RunEvents.Active(addon)
    local run = validName(addon) and openRun()
    if run and run.addon == addon then return run.planTitle end
    return nil
end
