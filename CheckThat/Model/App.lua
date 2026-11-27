-- Application logic: import, runs, verdicts, export. Testable with a fake env; no frames here.
local _, ns = ...
local L = ns.L
local App = { db = nil, env = _G }
ns.App = App

local function now(self) return (self.env.time and self.env.time()) or 0 end

-- db is the saved global table. opts.debug() says whether recording is on (default: db.log.enabled).
-- A run saved in a newer major format is kept aside, untouched: this version cannot read it right, and a pass over it
-- (normalizing, touching, pruning, counting) could damage it. Every other part of the addon then never sees it. It moves back
-- when a CheckThat that reads its format loads it.
-- The shape of the saved global table (#248). A table without dbRev is from 0.21.0 or older, rev 0, the same shape as rev 1. A migration
-- moves the table from one rev to the next: MIGRATIONS[n] takes rev n - 1 to rev n, changes only keys it knows, and never deletes data it
-- cannot rebuild. A table from a newer CheckThat (dbRev above DB_REV) is left as it is: this version never writes a lower rev over it.
-- dbRev is written here and not in Core/Defaults.lua, because AceDB drops a saved value that equals its default.
App.DB_REV = 1
App.MIGRATIONS = {}
function App.Migrate(db)
    local rev = db.dbRev
    if rev == nil then rev = 0 end
    if type(rev) ~= "number" or rev % 1 ~= 0 or rev < 0 then return "unreadable" end
    if rev > App.DB_REV then return "newer" end
    for n = rev + 1, App.DB_REV do
        local step = App.MIGRATIONS[n]
        if step then step(db) end
        db.dbRev = n
    end
    return rev < App.DB_REV and "migrated" or "current", rev
end

function App.SplitFuture(db)
    for id, run in pairs(db.runs) do
        if ns.Run.Opaque(run) then
            db.future = db.future or {}
            if db.future[id] == nil then
                db.future[id], db.runs[id] = run, nil
                -- Which plan it needs is unknown, so the plans stored now stay. Plans imported later can still go.
                if type(run.planDigest) ~= "string" then
                    db.futureKeep = db.futureKeep or {}
                    for digest in pairs(db.planStore or {}) do db.futureKeep[digest] = true end
                end
            end -- else an entry with that id is already aside: both stay where they are
        end
    end
    for id, run in pairs(db.future or {}) do
        if not ns.Run.Opaque(run) and db.runs[id] == nil then db.runs[id], db.future[id] = run, nil end -- never over a readable run
    end
    if db.future and next(db.future) == nil then db.future, db.futureKeep = nil, nil end
end

function App.FutureCount()
    local n = 0
    for _ in pairs(App.db and App.db.future or {}) do n = n + 1 end
    return n
end

-- The open run of this character, or nil.
local function openRun()
    local run = App.db and App.db.runs[App.db.currentByChar[App.Character()] or ""]
    if run and not run.endedAt then return run end
    return nil
end

-- Tell the addons that a change of the open run happened. Always after the state is saved.
local function changed(before, reason)
    if ns.RunEvents then ns.RunEvents.Changed(before, openRun(), reason) end
end

-- True while the character has an open run. The login self-check stays out of the way of a run.
function App.RunOpen()
    local run = App.db and App.db.runs[App.db.currentByChar[App.Character()] or ""]
    return run ~= nil and not run.endedAt
end

function App.Init(db, env, opts)
    App.env = env or _G
    local migrated, from = App.Migrate(db)
    db.plans = db.plans or {}
    db.planStore = db.planStore or {}
    db.currentByChar = db.currentByChar or {}
    db.runs = db.runs or {}
    App.SplitFuture(db)
    db.log = db.log or { entries = {} }
    db.ui = db.ui or {}
    db.ui.shareReload = nil -- a reload request lasts until the next load
    db.facts = db.facts or {}
    db.errors = db.errors or {}
    db.errorStacks = db.errorStacks or {}
    App.db = db
    if migrated == "migrated" then App.Log(("saved data rev %d -> %d"):format(from, App.DB_REV))
    elseif migrated ~= "current" then App.Log(("saved data rev %s is %s; left as it is"):format(tostring(db.dbRev), migrated)) end
    -- Facts and errors belong to the character's open run, also while the card shows another run.
    local function runOpen()
        local run = App.db.runs[App.db.currentByChar[App.Character()] or ""]
        return run ~= nil and not run.endedAt
    end
    if ns.Facts then ns.Facts.Bind(db.facts, function() return now(App) end, runOpen) end
    if ns.RunEvents then ns.RunEvents.Bind(openRun) end
    if ns.Entries then
        -- Unknown is treated as combat: an entry never runs when the game cannot say.
        ns.Entries.Bind(function()
            local f = App.env.InCombatLockdown
            if type(f) ~= "function" then return true end
            local ok, r = pcall(f)
            if not ok then return true end
            return r and true or false
        end)
    end
    if ns.Errors then
        ns.Errors.Bind(db.errors, function() return now(App) end, runOpen, App.env, db.errorStacks)
    end
    db.blocked = db.blocked or {}
    if ns.Blocked then
        ns.Blocked.Bind(db.blocked, function() return now(App) end, runOpen)
    end
    if ns.Log then
        ns.Log.Bind(db.log, (opts and opts.debug) or function() return db.log.enabled end, function() return now(App) end)
    end
    return db
end

function App.Log(msg)
    if ns.Log then ns.Log.Record("ct", msg) end
end

-- "classic-era" or "forever-camelot", from the interface number (checked by number, not by client name). nil when the
-- number is unknown or names neither (#252): a step tagged for one client then does not run.
function App.Client()
    local gb = App.env.GetBuildInfo
    local toc
    if gb then local _, _, _, t = gb(); toc = tonumber(t) end
    if not toc then return nil end
    if toc >= 16000 and toc < 17000 then return "forever-camelot" end
    if toc >= 11000 and toc < 12000 then return "classic-era" end
    return nil
end

function App.Build()
    local gb = App.env.GetBuildInfo
    if not gb then return "unknown" end
    local v, b = gb()
    return tostring(v) .. "." .. tostring(b)
end

function App.Character()
    local env = App.env
    local n, r = env.UnitName and env.UnitName("player"), nil
    if env.UnitFullName then
        local fn, fr = env.UnitFullName("player")
        n = fn or n; r = fr
    end
    for _, get in ipairs({ env.GetNormalizedRealmName, env.GetRealmName }) do
        if (r == nil or r == "") and get then r = get() end
    end
    if r == nil or r == "" then r = "?" end
    return (n or "?") .. "-" .. r
end

-- Codec and plan errors are technical English; the player sees one of these sentences.
local function readError(err)
    err = tostring(err)
    if err:find("checksum") then return L["The checksum does not match. The string may be damaged."] end
    if err:find("too large") then return L["The string is too large."] end
    if err:find("version") then return L["This string needs a newer CheckThat."] end
    if err:find("not a CT") then return L["This is not a CheckThat string."] end
    return L["The string is damaged or incomplete."]
end

-- Recently used plans, newest first (max 8). Each entry names a stored plan by digest, so a plan can be chosen
-- again without pasting its string.
App.RECENT_MAX = 8

function App.RememberRecent(plan, digest)
    local list = App.db.ui.recent or {}
    local out = { { digest = digest, addon = plan.addon, title = plan.title, at = now(App) } }
    for _, e in ipairs(list) do
        if e.digest ~= digest and #out < App.RECENT_MAX then out[#out + 1] = e end
    end
    App.db.ui.recent = out
    App.db.ui.lastImport = plan.addon
end

-- A title cut for a one-line list entry: color codes removed, at most max bytes with "..." in place of the rest,
-- never cut inside a UTF-8 character. A long plan title ran past both edges of the import dropdown.
App.ENTRY_TITLE_MAX = 48
function App.ShortTitle(s, max)
    s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    max = max or App.ENTRY_TITLE_MAX
    if #s <= max then return s end
    local cut = max - 3
    while cut > 0 and (s:byte(cut + 1) or 0) >= 0x80 and s:byte(cut + 1) < 0xC0 do cut = cut - 1 end
    return s:sub(1, cut):gsub("%s+$", "") .. "..."
end

-- Entries whose plan is still stored: { id = digest, text = "Title (Addon)" }, the title cut to fit one line.
function App.Recent()
    local out = {}
    for _, e in ipairs(App.db and App.db.ui.recent or {}) do
        if App.db.planStore[e.digest] then out[#out + 1] = { id = e.digest, text = ("%s (%s)"):format(App.ShortTitle(e.title), e.addon) } end
    end
    return out
end

-- Make a recent plan the current one, as if it had just been imported.
function App.UseRecent(digest)
    local plan = App.db.planStore[digest]
    if not plan then return nil, L["That plan is no longer stored. Paste its string again."] end
    App.db.plans[plan.addon] = { plan = plan, digest = digest }
    App.RememberRecent(plan, digest)
    App.db.ui.pendingStart = plan.addon
    App.Log(("reused plan %s digest %s"):format(plan.addon, digest))
    return plan
end

-- The plans CheckThat ships (#246). The import list pins the self-test first; a recent entry for the same plan is left out.
App.BUILTIN = "builtin:selftest"
function App.ImportChoices()
    local s = ns.BuiltIn and ns.BuiltIn.selftest
    if not s then return App.Recent() end
    local digest = s:match("^!CT1!(%x+)!")
    local out = { { id = App.BUILTIN, text = L["CheckThat self-test (built-in)"] } }
    for _, e in ipairs(App.Recent()) do
        if e.id ~= digest then out[#out + 1] = e end
    end
    return out
end

-- The string to import for a choice from ImportChoices, or nil for a recent plan.
function App.BuiltInString(id)
    return id == App.BUILTIN and ns.BuiltIn and ns.BuiltIn.selftest or nil
end

-- A stored plan copy stays only while a run, a loaded plan or a recent-list entry names it.
function App.PrunePlans()
    local keep = {}
    for _, r in pairs(App.db.future or {}) do
        if type(r.planDigest) == "string" then keep[r.planDigest] = true end
    end
    for digest in pairs(App.db.futureKeep or {}) do keep[digest] = true end -- a run that names no plan may need one stored when it was set aside
    for _, r in pairs(App.db.runs) do if r.planDigest then keep[r.planDigest] = true end end
    for _, p in pairs(App.db.plans) do keep[p.digest] = true end
    for _, e in ipairs(App.db.ui.recent or {}) do keep[e.digest] = true end
    for digest in pairs(App.db.planStore) do
        if not keep[digest] then App.db.planStore[digest] = nil end
    end
end

App.RUN_LIMIT = { default = 20, min = 5, max = 100 }

function App.RunLimit()
    local n = App.db and tonumber(App.db.runLimit)
    if not n then return App.RUN_LIMIT.default end
    return math.max(App.RUN_LIMIT.min, math.min(App.RUN_LIMIT.max, math.floor(n)))
end

-- Runs newest first; ties keep a stable order by id.
local function sortedRuns()
    local list = {}
    for id, run in pairs(App.db.runs) do list[#list + 1] = { id = id, run = run } end
    table.sort(list, function(a, b)
        local x, y = a.run.started or 0, b.run.started or 0
        if x ~= y then return x > y end
        return a.id > b.id
    end)
    return list
end

-- Keep at most RunLimit runs: the oldest go first. A character's current run always stays.
function App.PruneRuns()
    local list, current = sortedRuns(), {}
    for _, id in pairs(App.db.currentByChar) do current[id] = true end
    local excess = #list - App.RunLimit()
    for i = #list, 1, -1 do
        if excess <= 0 then break end
        if not current[list[i].id] then
            App.db.runs[list[i].id] = nil
            excess = excess - 1
            App.Log("run pruned " .. list[i].id)
        end
    end
    App.PrunePlans()
end

-- The run the card shows: an ended run opened from Past runs, else the character's current run.
local function shownId()
    local char = App.Character()
    local v = App.db.ui.view and App.db.ui.view[char]
    if v and App.db.runs[v] then return v end
    return App.db.currentByChar[char]
end
App.ShownId = shownId

local function runText(run)
    local c = ns.Run.Counts(run)
    local when = run.started and App.env.date and App.env.date("%Y-%m-%d %H:%M", run.started) or tostring(run.started or "?")
    local fmt = run.endedAt and L["%s  %s (%s): %d pass, %d fail, %d open, ended"] or L["%s  %s (%s): %d pass, %d fail, %d open"]
    return fmt:format(when, tostring(run.planTitle or run.addon), tostring(run.character), c.pass, c.fail, c.open)
end

-- A short row for the Runs dropdown: the pull-out grows with its longest row, so the text stays narrow.
local function rowText(run)
    local c = ns.Run.Counts(run)
    local when = run.started and App.env.date and App.env.date("%m-%d %H:%M", run.started) or tostring(run.started or "?")
    local title = tostring(run.planTitle or run.addon)
    if #title > 24 then title = title:sub(1, 24):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
    local fmt = run.endedAt and L["%s  %s (%s): %d/%d/%d, ended"] or L["%s  %s (%s): %d/%d/%d"]
    return fmt:format(when, title, tostring(run.character):match("^[^-]+") or "?", c.pass, c.fail, c.open)
end

function App.RunText(id)
    local run = App.db.runs[id or ""]
    return run and runText(run) or nil
end

-- Rows for the Runs list, newest first: { id, text, ended, character, current }.
function App.Runs()
    local out = {}
    local cur = App.db.currentByChar[App.Character()]
    for _, e in ipairs(sortedRuns()) do
        out[#out + 1] = { id = e.id, ended = e.run.endedAt ~= nil, character = e.run.character, current = e.id == cur, text = rowText(e.run) }
    end
    return out
end

-- Show a stored run on the card. An ended run is only viewed: the character's current run stays as it was.
-- A run that has not ended belongs to the character that started it: it becomes the current run, and the
-- attempt it left open starts again. Another character cannot take it over.
function App.OpenRun(id)
    local run = App.db.runs[id or ""]
    if not run then return nil, L["There is no run."] end
    local char, ui = App.Character(), App.db.ui
    local before = openRun()
    ui.view = ui.view or {}
    if run.endedAt then
        ui.view[char] = App.db.currentByChar[char] ~= id and id or nil
    elseif run.character ~= char then
        return nil, L["That run has not ended and belongs to another character. Export it or delete it."]
    else
        ui.view[char] = nil
        if App.db.currentByChar[char] ~= id then
            App.db.currentByChar[char] = id
            ns.Run.Resume(run, now(App))
        end
    end
    ui.pendingStart = nil
    App.Log("run opened " .. id)
    changed(before, "replaced")
    return run
end

-- True when opening this run would take the card from another unfinished run of this character.
function App.OpenReplacesRun(id)
    local run = App.db.runs[id or ""]
    local cur = App.db.runs[App.db.currentByChar[App.Character()] or ""]
    return run ~= nil and not run.endedAt and cur ~= nil and not cur.endedAt and cur.runId ~= id
end

-- True when opening this run needs the player's accept: another unfinished run of this character is active.
function App.OpenAsks(id)
    local cur = App.db.runs[App.db.currentByChar[App.Character()] or ""]
    return App.db.runs[id or ""] ~= nil and cur ~= nil and not cur.endedAt and cur.runId ~= id
end

function App.DeleteRun(id)
    if not App.db.runs[id or ""] then return nil, L["There is no run."] end
    local before = openRun()
    App.db.runs[id] = nil
    for char, cur in pairs(App.db.currentByChar) do
        if cur == id then App.db.currentByChar[char] = nil end
    end
    for char, v in pairs(App.db.ui.view or {}) do
        if v == id then App.db.ui.view[char] = nil end
    end
    App.PrunePlans()
    App.Log("run deleted " .. id)
    changed(before, "deleted")
    return true
end

-- Import a pasted string. Returns plan table or nil + error text. Nothing is stored on failure.
-- Validator messages are technical English kept for the debug log; the player sees one of these sentences.
local function planReason(first)
    first = tostring(first)
    if first:find("^markdown") then return L["A text in the plan uses backticks or stars. Plans use game color codes."] end
    if first:find("not allowed") then return L["The plan has a command that CheckThat does not allow."] end
    if first:find(": pattern ") or first:find(": matches pattern ") then return L["The plan has a text pattern that the game cannot read. Write the pattern again."] end
    if first:find("addon not supported") then return L["This plan is for an addon this CheckThat does not support."] end
    if first:find("format version") then return L["This string needs a newer CheckThat."] end
    local need, have = first:match("^needs plan revision (%d+); this version reads up to (%d+)")
    if need then return L["This plan needs a newer CheckThat. It uses plan revision %d, and this version reads up to %d."]:format(tonumber(need), tonumber(have)) end
    return L["The plan has a missing or wrong field. Export it again from the plan file."]
end

local function sameTable(a, b)
    local x, y = ns.Json.Encode(a), ns.Json.Encode(b)
    return x ~= nil and x == y
end

function App.ImportPlan(str)
    local ok, tbl, err, digest = pcall(ns.Codec.Decode, str)
    if not ok then App.Log("import crashed: " .. tostring(tbl)); return nil, L["The string could not be read. %s"]:format(readError("damaged")) end
    if not tbl then App.Log("import failed: " .. tostring(err)); return nil, L["The string could not be read. %s"]:format(readError(err)) end
    if type(tbl) ~= "table" then return nil, L["The string could not be read. %s"]:format(readError("damaged")) end
    if tbl.kind ~= "plan" then return nil, L["This string holds %s, not a plan."]:format(tostring(tbl.kind):gsub("[^%w ]", "")) end
    local vok, errs = pcall(ns.Plan.Validate, tbl, App.commands[tbl.addon])
    if not vok then errs = { "validator error: " .. tostring(errs) } end
    if #errs > 0 then
        App.Log("import rejected: " .. errs[1])
        return nil, L["The plan is not valid (%d problems). %s"]:format(#errs, planReason(errs[1]))
    end
    -- The checksum is only 32 bits: never let a different plan take over a stored one that a run depends on.
    local key, n = digest, 1
    while App.db.planStore[key] and not sameTable(App.db.planStore[key], tbl) do n = n + 1; key = digest .. "-" .. n end
    digest = key
    App.db.plans[tbl.addon] = { plan = tbl, digest = digest }
    App.db.planStore[digest] = tbl -- runs keep the exact plan they started with
    App.RememberRecent(tbl, digest)
    App.db.ui.pendingStart = tbl.addon -- a new plan takes focus: the card offers Start run, even after a finished run
    App.PrunePlans()
    App.Log(("imported plan %s digest %s"):format(tbl.addon, digest))
    return tbl
end

function App.Ctx(run)
    local plan = run.planDigest and App.db.planStore[run.planDigest]
    if not plan then return nil end
    ns.Run.Normalize(run, plan, run.client)
    return { plan = plan, planDigest = run.planDigest, client = run.client, build = App.Build(),
        character = run.character, now = now(App), env = App.env }
end

-- The globals a plan reads, sorted: each log source's global and each global-value probe's name. What they hold can reach the
-- results string (log lines, excerpts, "observed"). A frame-shown probe is left out: it saves only whether the frame is shown.
function App.PlanReads(plan)
    local seen, out = {}, {}
    local function add(name)
        if type(name) == "string" and name ~= "" and not seen[name] then seen[name] = true; out[#out + 1] = name end
    end
    for _, src in pairs(type(plan.logs) == "table" and plan.logs or {}) do add(type(src) == "table" and src.global or nil) end
    for _, sec in ipairs(plan.sections or {}) do
        for _, st in ipairs(sec.steps or {}) do
            for _, a in ipairs(type(st.assertions) == "table" and st.assertions or {}) do
                if a.probe == "global-value" then add(a.name) end
            end
        end
    end
    table.sort(out)
    return out
end

-- The note for the start screen: what the plan reads, so the tester knows what the results string may include. nil when it reads nothing.
App.READS_SHOWN = 6
function App.ReadsNote(plan)
    local names = App.PlanReads(plan)
    if #names == 0 then return nil end
    local shown = {}
    for i = 1, math.min(#names, App.READS_SHOWN) do shown[i] = (names[i]:sub(1, 40):gsub("|", "||")) end
    local list = table.concat(shown, ", ")
    if #names > App.READS_SHOWN then list = L["%s, and %d more"]:format(list, #names - App.READS_SHOWN) end
    return L["This plan reads these variables: %s. A results string can include what they hold."]:format(list)
end

-- The categories of a plan with how many steps each has for this client: { { id, title, steps } }.
function App.CategoryChoices(plan)
    local out, byId = {}, {}
    for _, c in ipairs((ns.Plan.Categories(plan))) do
        byId[c.id] = { id = c.id, title = c.title, steps = 0 }
        out[#out + 1] = byId[c.id]
    end
    for _, e in ipairs((ns.Plan.Steps(plan, App.Client()))) do
        local c = byId[e.category]
        if c then c.steps = c.steps + 1 end
    end
    return out
end

-- The categories the tester can pick for the next run of a plan, in plan order: { id, title, steps, picked }.
-- Every category starts picked; only the ones the tester cleared are remembered.
function App.Picks(addon)
    local rec = App.db.plans[addon or ""]
    if not rec then return {} end
    local off = App.db.ui.cleared and App.db.ui.cleared[addon] or {}
    local out = App.CategoryChoices(rec.plan)
    for _, c in ipairs(out) do c.picked = not off[c.id] end
    return out
end

function App.SetPick(addon, id, on)
    App.db.ui.cleared = App.db.ui.cleared or {}
    local off = App.db.ui.cleared[addon] or {}
    off[id] = (not on) or nil
    App.db.ui.cleared[addon] = next(off) and off or nil
end

-- The ids to start a run with, or nil when the plan has one category (no choice to make).
function App.PickedIds(addon)
    local list = App.Picks(addon)
    if #list < 2 then return nil end
    local ids = {}
    for _, c in ipairs(list) do if c.picked and c.steps > 0 then ids[#ids + 1] = c.id end end
    return ids
end

-- picks is a list of category ids, or nil to run every category.
function App.Start(addon, picks)
    local rec = App.db.plans[addon]
    if not rec then return nil, L["No plan is imported for %s."]:format(tostring(addon)) end
    local known = {}
    for _, c in ipairs((ns.Plan.Categories(rec.plan))) do known[c.id] = true end
    for _, id in ipairs(picks or {}) do
        if not known[id] then return nil, L["There is no category called %s."]:format(ns.Slash.Esc(id)) end
    end
    local ctx = { plan = rec.plan, planDigest = rec.digest, client = App.Client(), build = App.Build(),
        character = App.Character(), now = now(App), env = App.env, selected = picks,
        targetVersion = ns.Adapter.AddonVersion(rec.plan.addon) }
    local run = ns.Run.New(ctx)
    if not run then return nil, picks and L["Pick at least one category that has steps for this client."] or L["The plan has no steps for this client."] end
    local before = openRun()
    if ns.Errors then ns.Errors.Hook(); ns.Errors.Rebase() end
    while App.db.runs[run.runId] or (App.db.future and App.db.future[run.runId]) do run.runId = run.runId .. "x" end
    App.db.runs[run.runId] = run
    App.db.currentByChar[App.Character()] = run.runId
    if App.db.ui.view then App.db.ui.view[App.Character()] = nil end
    App.db.planStore[rec.digest] = rec.plan
    App.db.ui.pendingStart = nil
    App.PruneRuns()
    App.Log("run started " .. run.runId)
    local offered, missing = App.CommandsCheck(rec.plan, true)
    if #offered + #missing > 0 then
        App.Log(("plan commands offered: %s; not offered: %s"):format(#offered > 0 and table.concat(offered, " ") or "none", #missing > 0 and table.concat(missing, " ") or "none"))
    end
    App.JudgeAtStart(run, ctx)
    changed(before, "replaced")
    return run
end

function App.Current()
    local id = App.db and shownId()
    local run = id and App.db.runs[id]
    if not run then return nil end
    local ctx = App.Ctx(run)
    if not ctx then return nil end
    local sid = ns.Run.CurrentId(run)
    local step = sid and ns.Run.stepOf(ctx, sid)
    return run, ctx, step
end

-- What the tester can copy for this step: allowed slash commands, then macro text.
function App.Copyables(step, plan)
    local out = {}
    local a = step.action
    -- One command per box: a multi-line macro pasted as one line would change its meaning.
    local function add(text)
        for line in ((text or "") .. "\n"):gmatch("(.-)\n") do if line ~= "" then out[#out + 1] = line end end
    end
    if a.kind == "copy-slash" then add(a.text) end
    for _, c in ipairs(a.commands or {}) do add(c) end
    if a.kind == "secure-macro" then
        for _, m in ipairs(plan.macros or {}) do if m.id == a.macro then add(m.text) end end
    end
    if a.kind == "reload" then add("/reload") end
    return out
end

-- Commands an addon declared through CheckThat.Commands: [addon] = { ["/cmd"] = true }. The addon's own code says them, so
-- they need no check in game; a plan can never add to them.
App.commands = App.commands or {}
function App.DeclareCommands(addon, list)
    if type(addon) ~= "string" or #addon > ns.Plan.ADDON_MAX or not addon:match(ns.Plan.ADDON_NAME) then return false end
    if type(list) ~= "table" or #list == 0 or #list > ns.Plan.COMMANDS_MAX then return false end
    local set = {}
    for _, c in ipairs(list) do
        if ns.Plan.CommandProblem(c, addon) then return false end
        set[c:lower()] = true
    end
    App.commands[addon] = set
    App.Log(("commands declared by %s: %d"):format(addon, #list))
    return true
end

-- The plan's own commands, split by what the game says: offered when the addon under test registered the command
-- (a SLASH_ global it wrote), not offered otherwise (another addon's, the game's, or not registered yet). Kept per plan
-- until the next Start, because the check walks the game's command list.
local verified = setmetatable({}, { __mode = "k" })
function App.CommandsCheck(plan, fresh)
    if not fresh and verified[plan] then return verified[plan].offered, verified[plan].missing end
    local offered, missing = {}, {}
    local owner = App.env.SlashOwner
    for _, c in ipairs(type(plan.commands) == "table" and plan.commands or {}) do
        local cmd = type(c) == "string" and c:lower()
        local known = cmd and ((ns.Plan.SLASH[plan.addon] or {})[cmd] or (App.commands[plan.addon] or {})[cmd])
        if cmd and not ns.Plan.CommandProblem(cmd, plan.addon) and (known or (type(owner) == "function" and owner(cmd) == plan.addon)) then
            offered[#offered + 1] = cmd
        elseif cmd then missing[#missing + 1] = cmd end
    end
    verified[plan] = { offered = offered, missing = missing }
    return offered, missing
end

-- Every command a Run button or the CT macro may run for this plan: the known list, the addon's declared commands, and the
-- plan's commands the game says belong to the addon under test.
function App.AllowedCommands(plan)
    local allow = {}
    for c in pairs(ns.Plan.SLASH[plan.addon] or {}) do allow[c] = true end
    for c in pairs(App.commands[plan.addon] or {}) do allow[c] = true end
    for _, c in ipairs((App.CommandsCheck(plan))) do allow[c] = true end
    return allow
end

-- The start screen line about a plan's own commands, or nil when it lists none.
function App.CommandsNote(plan)
    local offered, missing = App.CommandsCheck(plan, true)
    if #offered == 0 and #missing == 0 then return nil end
    local parts = {}
    if #offered > 0 then parts[#parts + 1] = L["This plan may offer these commands: %s."]:format(table.concat(offered, ", ")) end
    if #missing > 0 then parts[#parts + 1] = L["Not offered, because the addon under test has not registered them: %s."]:format(table.concat(missing, ", ")) end
    return table.concat(parts, " ")
end

-- The card has this many copy boxes. A macro with more lines is not offered as one button: it would run
-- commands the tester cannot see.
App.MAX_COPY = 4

-- The macro text a secure button or the "CT" macro would run, or nil. Always re-checked against the allow list.
function App.MacroText(step, plan)
    local a = step.action
    local text
    if a.kind == "secure-macro" then
        for _, m in ipairs(plan.macros or {}) do if m.id == a.macro then text = m.text end end
    elseif a.kind == "copy-slash" then text = a.text
    elseif a.kind == "reload" then text = "/reload"
    elseif type(a.commands) == "table" and #a.commands > 0 then text = table.concat(a.commands, "\n") end -- manual step with commands: Run does them in order
    if text and ns.Plan.MacroAllowed(text, App.AllowedCommands(plan)) then
        local lines = 0
        for line in (text .. "\n"):gmatch("(.-)\n") do if line ~= "" then lines = lines + 1 end end
        if lines <= App.MAX_COPY then return text end
    end
end

-- The first line of the CT macro, /ct macrorun <step id>. It only logs: a match is "macro run", another step is
-- "macro stale". Returns the chat line for a stale press. Never records a result.
function App.MacroRun(id)
    local run, ctx, step = App.Current()
    local cur = step and step.id
    if id == cur then App.Log("macro run " .. id); return nil end
    App.Log("macro stale " .. id .. " card " .. (cur or "none"))
    local rec = run and cur and not run.endedAt and run.steps[cur]
    if rec then rec.macroStale = (rec.macroStale or 0) + 1; ns.Run.Touch(run, ctx.now) end
    if not cur then return L["This macro is for step %s. No step is open."]:format(id) end
    return L["This macro is for step %s. The card shows step %s."]:format(id, cur)
end

-- Section intro for the card, shown on the first step of a section that has no verdicts yet.
-- A result CheckThat recorded at run start (an async step) or a step that does not apply is not the tester's progress.
local function untouched(rec)
    if rec.verdict == "pending" or rec.verdict == "inapplicable" or rec.verdict == "deselected" then return true end
    local last = rec.attempts and rec.attempts[#rec.attempts]
    return last ~= nil and last.at == "start" and #rec.attempts == 1
end

function App.SectionIntro(run, ctx, stepId)
    local steps = ns.Plan.Steps(ctx.plan, run.client)
    local mine
    for _, e in ipairs(steps) do if e.step.id == stepId then mine = e end end
    if not (mine and mine.intro) then return nil end
    for _, e in ipairs(steps) do
        if e.sectionId == mine.sectionId then
            if not untouched(run.steps[e.step.id]) then return nil end
        end
    end
    return mine.intro
end

-- True until any step has a verdict: show the plan's preamble.
function App.AtStart(run)
    for _, rec in pairs(run.steps) do
        if not untouched(rec) then return false end
    end
    return true
end

-- Run.Begin or Run.Verdict, then ask for an error stack when the call opened a new attempt: an open one has its own.
local function opening(run, step, fn)
    local rec = run.steps[step.id]
    local before = rec and #rec.attempts
    local a, err = fn()
    if ns.Errors and rec and #rec.attempts ~= before then ns.Errors.StepStarted() end
    return a, err
end

-- The player ticked (on) or cleared listed action i of the current step. Logged; never a result.
function App.Tick(i, on)
    local run, ctx, step = App.Current()
    if not step then return false end
    ctx.now = now(App)
    local ok = ns.Run.Tick(run, ctx, step.id, i, on)
    if ok then App.Log(("step %s action %d %s"):format(step.id, i, on and "ticked" or "cleared")) end
    return ok
end

function App.Begin()
    local run, ctx, step = App.Current()
    if not step then return nil end
    if ns.Errors then ns.Errors.Watch(); ns.Errors.Sample() end
    local rec = run.steps[step.id]
    -- A requirement the character cannot meet (a class, a profession) makes the step inapplicable: no timer, no call.
    local unmet = rec and rec.verdict == "pending" and ns.Run.Unmet(ctx, step)
    if unmet then
        ns.Run.MarkInapplicable(run, ctx, step.id, unmet)
        App.Log(("step %s inapplicable: %s"):format(step.id, unmet))
        return nil, step, unmet
    end
    local last = rec and rec.attempts[#rec.attempts]
    local fresh = not (last and not last.verdict) -- a reload keeps its open attempt and its call
    local a = opening(run, step, function() return ns.Run.Begin(run, ctx, step.id) end)
    if fresh and step.call and step.auto and a and not a.noauto and ns.Entries then ns.Entries.Run(step.call) end
    return a, step
end

local function logResult(step, a)
    local why
    for _, o in ipairs(a.outcomes or {}) do if o.result ~= "pass" and not o.diagnostic then why = o.why; break end end
    App.Log(("step %s %s%s%s%s%s"):format(step.id, a.verdict, a.by == "auto" and " auto" or "", a.at == "start" and " at start" or "",
        a.evidence and (" evidence " .. a.evidence) or "", why and (": " .. why) or ""))
end

-- Async steps are judged when the run starts (or after a rerun), before any of them opens. Logs each pass.
function App.JudgeAtStart(run, ctx, ids)
    local before = {}
    for _, id in ipairs(run.order) do before[id] = run.steps[id].verdict end
    local n = ns.Run.JudgeAtStart(run, ctx, ids)
    if n > 0 then
        for _, id in ipairs(run.order) do
            local rec = run.steps[id]
            local a = rec.attempts[#rec.attempts]
            if before[id] == "pending" and rec.verdict == "pass" and a and a.at == "start" then logResult(ns.Run.stepOf(ctx, id), a) end
        end
    end
    return n
end

-- A step's cleanup (#247). After a result, the card shows it until the next step has a result. Saved in ui.cleanup,
-- so a reload keeps it; Undo or Redo of that step hides it again.
local FINAL = { pass = true, partial = true, fail = true, skip = true }
local function rememberCleanup(run, step, a)
    if not (App.db and run and step and a and FINAL[a.verdict]) then return end
    App.db.ui.cleanup = step.cleanup and { run = run.runId, step = step.id } or nil
    if step.cleanup then App.Log(("cleanup of %s shown next"):format(step.id)) end
end

-- The cleanup text to show now and the step it belongs to, or nil.
function App.Cleanup()
    local c = App.db and App.db.ui.cleanup
    if type(c) ~= "table" then return nil end
    local run, ctx = App.Current()
    if not (run and ctx and run.runId == c.run and not run.endedAt) then return nil end
    local rec = run.steps[c.step or ""]
    local from = rec and FINAL[rec.verdict] and ns.Run.stepOf(ctx, c.step)
    if not (from and type(from.cleanup) == "string") then return nil end
    return from.cleanup, from
end

function App.Verdict(verdict, note)
    local run, ctx, step = App.Current()
    if run and run.endedAt then return nil, L["This run has ended. Start the plan again for a new run."] end
    if not step then return nil, L["There is no current step."] end
    do -- A step that has a result is read-only until Redo or Undo opens it again.
        local rec = run.steps[step.id]
        local last = rec and rec.attempts[#rec.attempts]
        if last and last.verdict and rec.verdict ~= "pending" then
            App.Log(("verdict refused %s: step has a result"):format(step.id))
            return nil, L["This step has a result. Use Redo this step or Undo first."]
        end
    end
    if ns.Errors then
        local rec = run.steps[step.id]
        local last = rec and rec.attempts[#rec.attempts]
        if not last or last.verdict then ns.Errors.StepStarted() end -- this verdict opens its own attempt: arm before the errors are read
        ns.Errors.Watch(); ns.Errors.Sample(); ns.Errors.Check()
    end
    local a, err = ns.Run.Verdict(run, ctx, step.id, verdict, note)
    if a then logResult(step, a); rememberCleanup(run, step, a) end
    return a, err, step
end

-- Seconds until the current auto step settles itself, or nil.
function App.TimeLeft()
    local run, ctx, step = App.Current()
    if not (step and step.auto and step.timeout) then return nil end
    ctx.now = now(App)
    return ns.Run.TimeLeft(run, ctx, step.id)
end

-- The card's refresh calls this for the current step. Records a result only when the step is auto and its evidence says so.
function App.AutoSettle(note)
    local run, ctx, step = App.Current()
    if not (step and step.auto) then return nil end
    ctx.now = now(App)
    if ns.Errors then ns.Errors.Watch(); ns.Errors.Sample(); ns.Errors.Check() end
    local a = ns.Run.AutoSettle(run, ctx, step.id, note)
    if a then logResult(step, a); rememberCleanup(run, step, a) end
    return a, step
end

-- Calls every entry that an imported plan's auto step names and compares its fact line with the step's log checks.
-- Needs no run: nothing is recorded. Returns checked, matched, and the first miss as "step id: line" (nil when none).
-- A step counts as matched when it has at least one required equals or contains check and all of them hold.
function App.SelfCheck()
    local total, matched, miss = 0, 0, nil
    local names = {}
    for addon in pairs(App.db and App.db.plans or {}) do names[#names + 1] = addon end
    table.sort(names)
    for _, addon in ipairs(names) do
        local plan = App.db.plans[addon].plan
        for _, sec in ipairs(plan and plan.sections or {}) do
            for _, st in ipairs(sec.steps or {}) do
                if st.auto and st.call and ns.Entries then
                    total = total + 1
                    local line = ("[%s] entry.%s=%s"):format(st.call.addon, st.call.entry, ns.Entries.Outcome(st.call))
                    -- Only a plain equals or contains check on the facts list can be judged here. Anything else
                    -- (a count, an absence, another source, a fact operator) is not judged, so the step is a miss.
                    local rules, ok, why = 0, true, nil
                    for _, a in ipairs(st.assertions or {}) do
                        if not a.diagnostic then
                            local src = plan.logs and plan.logs[a.source]
                            local plain = a.kind == "log" and not a.absent and not a.count and not a.pattern and (a.equals or a.contains)
                                and src and src.path == "global.facts"
                            if not plain then ok = false; why = "check not judged at login"
                            else
                                rules = rules + 1
                                if not ((a.equals and a.equals == line) or (a.contains and line:find(a.contains, 1, true))) then ok = false end
                            end
                        end
                    end
                    if rules > 0 and ok then matched = matched + 1
                    elseif not miss then miss = st.id .. ": " .. (why or line) end
                end
            end
        end
    end
    App.Log(("self-check: %d of %d entry checks matched"):format(matched, total))
    return total, matched, miss
end

-- The open run of this character when its plan is saved, else nil. It is not always the run the card shows:
-- an ended run opened from Past runs is shown instead.
function App.OpenRecord()
    local run = openRun()
    return run and App.Ctx(run) and run or nil
end

-- The open attempt of the character's open run survived a reload: the card should ask for verification, not another reload.
-- Returns that run, or nil when the character has none (a past run that the card shows is not marked).
function App.MarkReloaded()
    local run = openRun()
    if not run then return nil end
    local ctx = App.Ctx(run)
    local sid = ctx and ns.Run.CurrentId(run)
    local step = sid and ns.Run.stepOf(ctx, sid)
    local rec = step and run.steps[step.id]
    local a = rec and rec.attempts[#rec.attempts]
    if a and not a.verdict then a.reloaded = true end
    return run
end

function App.Goto(delta)
    local run = App.Current()
    if not run then return nil end
    return ns.Run.Goto(run, delta)
end

-- The run /ct end and the card's End run act on: nil plus a sentence when there is none or it already ended.
function App.CanEnd()
    local run = App.db.runs[shownId() or ""]
    if not run then return nil, L["There is no run."] end
    if run.endedAt then return nil, L["This run has already ended."] end
    return run
end

-- End the current run. runId (optional) must still be the current run: a confirmation can outlive a change of run.
function App.End(runId)
    local run, err = App.CanEnd()
    if not run then return nil, err end
    if runId and run.runId ~= runId then return nil, L["There is no run."] end
    local before = openRun()
    ns.Run.End(run, now(App))
    App.Log("run ended " .. run.runId)
    changed(before, "ended")
    return run
end

-- End the current run and forget its plan: the loaded plan and its place in the recent list go. The stored copy stays,
-- so the ended run keeps its results screen and its export. runId is checked as for App.End.
function App.ClearPlan(runId)
    local run, err = App.End(runId)
    if not run then return nil, err end
    local ui = App.db.ui
    local loaded = App.db.plans[run.addon]
    local gone = { [run.planDigest or ""] = true, [loaded and loaded.digest or ""] = true }
    App.db.plans[run.addon] = nil
    if ui.pendingStart == run.addon then ui.pendingStart = nil end
    if ui.lastImport == run.addon then ui.lastImport = nil end
    local keep = {}
    for _, e in ipairs(ui.recent or {}) do if not gone[e.digest] then keep[#keep + 1] = e end end
    ui.recent = keep
    App.PrunePlans()
    App.Log("plan cleared " .. run.addon)
    return run
end

function App.Undo()
    local run, ctx = App.Current()
    if not run then return false end
    local ok, id = ns.Run.UndoLast(run, ctx)
    if ok then App.Log("undo " .. tostring(id) .. ": reopened") end
    return ok, id
end

function App.Export(runId)
    local run = App.db.runs[runId or shownId() or ""]
    if not run then return nil, L["There is no run."] end
    local copy = ns.Run.Export and ns.Run.Export(run) or run
    local s, err = ns.Codec.Encode(copy)
    if s then App.Log("run exported " .. run.runId) end
    return s, err
end

-- The words for category states: color is never the only signal.
function App.StateWord(state, counts)
    if state == "red" then return L["failed"] elseif state == "yellow" then return L["partial or unverified"]
    elseif state == "green" then return L["passed"] elseif state == "off" then return L["not picked"] end
    local resolved = counts and counts.resolved or 0
    if state == "blue" then return resolved > 0 and L["in progress"] or L["untested"] end
    return resolved > 0 and L["all skipped"] or L["no steps"]
end

-- Rows for the tracker, the Home list and /ct categories of the run on the card:
-- { id, title, state, counts, picked }, and the overall state with its counts.
function App.Categories()
    local run = App.db.runs[shownId() or ""]
    if not (run and run.categories) then return nil end
    local rows = {}
    for _, c in ipairs(run.categories) do
        local state, counts = ns.Run.CategoryState(run, c.id)
        rows[#rows + 1] = { id = c.id, title = c.title, state = state, counts = counts, picked = run.selected[c.id] == true }
    end
    local overall, total = ns.Run.OverallState(run)
    return rows, overall, total, run
end

-- One line for /ct categories and the Home list. The id is what /ct run and /ct rerun take.
-- The result in words for the caption: it names the count behind red and yellow.
function App.StatePhrase(state, c)
    if state == "red" then return L["%d failed"]:format(c.fail or 0) end
    if state == "yellow" then
        local p, u = c.partial or 0, c.unverified or 0
        if p > 0 and u > 0 then return L["%d partial, %d unverified"]:format(p, u) end
        if p > 0 then return L["%d partial"]:format(p) end
        return L["%d unverified"]:format(u)
    end
    return App.StateWord(state, c)
end

function App.CategoryLine(row)
    if not row.picked then return L["%s (%s): not picked"]:format(row.title, row.id) end
    local c = row.counts
    return L["%s (%s): %s, %d passed, %d failed, %d open"]:format(row.title, row.id, App.StateWord(row.state, c), c.pass, c.fail, c.open)
end

-- The state word and what happened to the steps, for a row of the Categories window.
function App.RowDetail(row)
    if not row.picked then return App.StateWord(row.state, row.counts) end
    local c = row.counts
    return L["%s · %d passed, %d failed, %d open"]:format(App.StateWord(row.state, c), c.pass, c.fail, c.open)
end

-- The steps of one category in plan order, also the ones that are not picked or not for this client, for the Categories window:
-- { id, title, verdict, word, offered }. A step that is not offered is listed but cannot be shown.
local STEP_WORD = {
    pass = L["passed"], fail = L["failed"], partial = L["partial"], unverified = L["unverified"], skip = L["skipped"],
    pending = L["open"], inapplicable = L["not for this client"], deselected = L["not picked"],
}
function App.CategorySteps(id)
    local run, ctx = App.Current()
    if not run then return {} end
    local out = {}
    for _, sec in ipairs(ctx.plan.sections) do
        for _, st in ipairs(sec.steps) do
            if run.cat[st.id] == id then
                local rec = run.steps[st.id]
                local v = rec and rec.verdict or "pending"
                out[#out + 1] = { id = st.id, title = st.title, verdict = v, word = STEP_WORD[v] or v, offered = v ~= "deselected" and v ~= "inapplicable" }
            end
        end
    end
    return out
end

-- Show one step on the card (a click on a step row). Only a step id counts, never a category name. Returns true, or nil and text.
function App.ShowStep(id)
    local run, ctx = App.Current()
    if not run then return nil, L["There is no run."] end
    local ok = ns.Run.Show(run, ctx, id)
    if not ok then return nil, L["That step is not in this run."] end
    App.Log("show step " .. tostring(id))
    return true
end

-- The run the player can change: the one on the card, when it has not ended.
local function activeRun()
    local run, ctx = App.Current()
    if not run then return nil, nil, L["There is no run."] end
    if run.endedAt then return nil, nil, L["This run has ended."] end
    return run, ctx
end

local function name(run, id)
    local c = ns.Run.CategoryOf(run, id)
    return ns.Slash.Esc(c and c.title or id)
end

-- Show a category (its first open step, picking the category first) or a step. Returns kind, step id, or nil and text.
function App.Trigger(what)
    local run, ctx, err = activeRun()
    if not run then return nil, err end
    if ns.Errors then ns.Errors.Hook() end
    local kind, id = ns.Run.Trigger(run, ctx, what)
    if not kind then
        local key = tostring(what or ""):lower()
        if id == "done" then return nil, L["Every step in %s has a result. Use /ct rerun %s to run them again."]:format(name(run, key), ns.Slash.Esc(key)) end
        if id == "ambiguous" then return nil, L["The name %s is both a category and a step, so nothing changed. Use the other name."]:format(ns.Slash.Esc(what or "")) end
        if id == "not for this client" then return nil, L["That step is not for this client."] end
        return nil, L["There is no category or step called %s."]:format(ns.Slash.Esc(what or ""))
    end
    App.Log(("trigger %s %s: step %s"):format(kind, tostring(what):lower(), id))
    return kind, id
end

-- Pick a category and leave the viewed step as it is. Returns true, false when it was already picked, or nil and text.
function App.Select(what)
    local run, ctx, err = activeRun()
    if not run then return nil, err end
    local key = tostring(what or ""):lower()
    local ok, why = ns.Run.Select(run, ctx, key)
    if ok == nil then return nil, L["There is no category called %s."]:format(ns.Slash.Esc(what or "")) end
    if ok then
        App.Log("select " .. key)
        local added = {}
        for _, id in ipairs(run.order) do if run.cat[id] == key then added[#added + 1] = id end end
        App.JudgeAtStart(run, ctx, added) -- an added category's async steps are judged as at run start
    end
    return ok
end

-- Can the category leave the run now? The card menu shows Remove from run only then.
-- The menu passes the exact id; a typed name is lower case, so ids that differ only in case stay apart.
local function categoryKey(run, what)
    what = tostring(what or "")
    return ns.Run.CategoryOf(run, what) and what or what:lower()
end

function App.CanDeselect(what)
    local run = App.Current()
    return run ~= nil and ns.Run.DeselectBlock(run, categoryKey(run, what)) == nil
end

-- Take a category out of the run. Returns true, or nil and text.
function App.Deselect(what)
    local run, ctx, err = activeRun()
    if not run then return nil, err end
    local key = categoryKey(run, what)
    local ok, why = ns.Run.Deselect(run, ctx, key)
    if ok then App.Log("deselect " .. key); return true end
    if why == "unknown category" then return nil, L["There is no category called %s."]:format(ns.Slash.Esc(what or "")) end
    if why == "not picked" then return nil, L["%s is not part of this run. Use /ct run %s to add it."]:format(name(run, key), ns.Slash.Esc(key)) end
    if why == "has results" then return nil, L["%s has results, so it stays in the run."]:format(name(run, key)) end
    return nil, L["A run needs at least one category."]
end

-- How many steps a rerun would reopen: the picked steps of the category that have a result.
function App.RerunCount(what)
    local run, _, err = activeRun()
    if not run then return nil, err end
    local key = tostring(what or ""):lower()
    if key == ns.Run.FAILED and not ns.Run.CategoryOf(run, key) then
        local n = 0
        for _, sid in ipairs(run.order) do
            local v = run.steps[sid].verdict
            if v == "fail" or v == "unverified" then n = n + 1 end
        end
        return n, L["failed and unverified steps"]
    end
    if not ns.Run.CategoryOf(run, key) then return nil, L["There is no category called %s."]:format(ns.Slash.Esc(what or "")) end
    if not run.selected[key] then return nil, L["%s is not part of this run. Use /ct run %s to add it."]:format(name(run, key), ns.Slash.Esc(key)) end
    local n = 0
    for _, sid in ipairs(run.order) do
        if run.cat[sid] == key and run.steps[sid].verdict ~= "pending" then n = n + 1 end
    end
    return n, name(run, key)
end

-- What to say when a rerun has nothing to reopen.
function App.NothingToReopen(what, title)
    if tostring(what or ""):lower() == ns.Run.FAILED and title == L["failed and unverified steps"] then return L["No step has failed or is unverified."] end
    return L["Nothing to reopen in %s: no step has a result."]:format(title)
end

-- Reopen the picked steps of a category. Returns how many steps reopened, or nil and text.
function App.Rerun(what)
    local run, ctx, err = activeRun()
    if not run then return nil, err end
    local key = tostring(what or ""):lower()
    local was = {}
    for _, id in ipairs(run.order) do was[id] = run.steps[id].verdict end
    local n, why = ns.Run.Rerun(run, ctx, what)
    if not n then
        if why == "not picked" then return nil, L["%s is not part of this run. Use /ct run %s to add it."]:format(name(run, key), ns.Slash.Esc(key)) end
        return nil, L["There is no category called %s."]:format(ns.Slash.Esc(what or ""))
    end
    App.Log(("rerun %s: %d steps reopened"):format(key, n))
    local reopened = {}
    for _, id in ipairs(run.order) do if was[id] ~= "pending" and run.steps[id].verdict == "pending" then reopened[#reopened + 1] = id end end
    ctx.now = now(App); App.JudgeAtStart(run, ctx, reopened)
    return n, (key == ns.Run.FAILED and not ns.Run.CategoryOf(run, key)) and L["failed and unverified steps"] or name(run, key)
end

-- The status line of the run the card shows, or of the run given.
function App.Status(run)
    run = run or App.db.runs[shownId() or ""]
    if not run then return L["No run."] end
    local c = ns.Run.Counts(run)
    local line = L["%s: %d pass, %d partial, %d fail, %d unverified, %d skipped, %d left, %d not for this client or character (revision %d, saved on reload)"]:format(
        run.runId, c.pass, c.partial, c.fail, c.unverified, c.skip, c.pending, c.inapplicable, run.revision)
    if c.deselected > 0 then line = L["%s, %d not picked"]:format(line, c.deselected) end
    return run.endedAt and L["%s (run ended)"]:format(line) or line
end
