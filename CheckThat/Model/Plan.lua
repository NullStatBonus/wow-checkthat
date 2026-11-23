-- Plan validation (mirror of schema/test-plan.schema.json) and client filtering. Plans are data only.
local _, ns = ...
local Plan = {}
ns.Plan = Plan

Plan.CLIENTS = { ["classic-era"] = true, ["forever-camelot"] = true }
Plan.ACTIONS = { manual = true, ["copy-slash"] = true, ["secure-macro"] = true, reload = true, ["wait-event"] = true }
Plan.VERIFY = { player = true, assertions = true, reviewer = true }
-- Runner-shipped slash allow list per addon. A plan can never extend it.
Plan.SLASH = {
    CheckThat = { ["/ct"] = true, ["/checkthat"] = true },
    KeepThat = { ["/kt"] = true, ["/keepthat"] = true },
    DontDoThat = { ["/ddt"] = true, ["/dontdothat"] = true },
    ClosestVendor = { ["/cvn"] = true, ["/closestvendor"] = true },
}
Plan.PROBES = { ["addon-loaded"] = true, ["global-value"] = true, ["frame-shown"] = true }
Plan.OPS = { eq = true, ne = true, gt = true, lt = true, contains = true, exists = true }
Plan.BUILTIN_SLASH = { ["/reload"] = true, ["/reloadui"] = true, ["/console"] = true }

local function isStr(v) return type(v) == "string" and v ~= "" end

-- Is every line of a macro a slash command from the allow list?
function Plan.MacroAllowed(text, allow)
    if not isStr(text) or #text > 255 then return false end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            local cmd = line:match("^(/%S+)")
            if not cmd then return false end
            cmd = cmd:lower()
            if not (Plan.BUILTIN_SLASH[cmd] or (allow and allow[cmd])) then return false end
            if cmd == "/console" and not line:lower():match("^/console%s+scripterrors%s+[01]%s*$") then return false end
        end
    end
    return true
end

local function checkAssertion(a, i, errs, logs, where)
    if type(a) ~= "table" then errs[#errs + 1] = where .. ": assertion " .. i .. " not a table"; return end
    for _, flag in ipairs({ "diagnostic", "absent" }) do
        if a[flag] ~= nil and type(a[flag]) ~= "boolean" then errs[#errs + 1] = where .. ": " .. flag .. " must be boolean" end
    end
    if a.kind == "log" then
        if not (logs and logs[a.source]) then errs[#errs + 1] = where .. ": unknown log source " .. tostring(a.source) end
        local n = (a.equals and 1 or 0) + (a.contains and 1 or 0) + (a.pattern and 1 or 0)
        if n ~= 1 then errs[#errs + 1] = where .. ": log assertion needs exactly one of equals, contains, pattern" end
        if a.scope ~= nil and a.scope ~= "attempt" and a.scope ~= "session" then errs[#errs + 1] = where .. ": bad scope" end
    elseif a.kind == "log-sequence" then
        if not (logs and logs[a.source]) then errs[#errs + 1] = where .. ": unknown log source " .. tostring(a.source) end
        if type(a.sequence) ~= "table" or #a.sequence == 0 then errs[#errs + 1] = where .. ": empty sequence" end
        for _, m in ipairs(a.sequence or {}) do
            local n = (m.equals and 1 or 0) + (m.contains and 1 or 0) + (m.pattern and 1 or 0)
            if n ~= 1 then errs[#errs + 1] = where .. ": sequence item needs exactly one of equals, contains, pattern" end
        end
    elseif a.kind == "state" then
        if not Plan.PROBES[a.probe] then errs[#errs + 1] = where .. ": unknown probe " .. tostring(a.probe) end
        if not Plan.OPS[a.op] then errs[#errs + 1] = where .. ": unknown op " .. tostring(a.op) end
    else errs[#errs + 1] = where .. ": unknown assertion kind " .. tostring(a.kind) end
end

-- An auto step is settled by its own evidence, so the evidence must be able to settle it alone.
function Plan.CheckAuto(st, w, errs)
    if st.auto ~= nil and type(st.auto) ~= "boolean" then errs[#errs + 1] = w .. ": auto must be boolean" end
    local isAuto = st.auto == true
    local act = st.action
    if type(act) == "table" and act.kind == "wait-event" and not isAuto then errs[#errs + 1] = w .. ": wait-event needs an auto step" end
    local t = st.timeout
    if t ~= nil then
        if not isAuto then errs[#errs + 1] = w .. ": timeout needs auto"
        elseif type(t) ~= "number" or t % 1 ~= 0 or t < 5 or t > 300 then
            errs[#errs + 1] = w .. ": timeout must be a whole number from 5 to 300"
        end
    end
    if not isAuto then return end
    local hasA, hasP
    for _, v in ipairs(type(st.verify) == "table" and st.verify or {}) do
        if v == "assertions" then hasA = true elseif v == "player" then hasP = true end
    end
    if not hasA then errs[#errs + 1] = w .. ": auto step needs assertions in verify" end
    if hasP then errs[#errs + 1] = w .. ": auto step cannot ask the player" end
    local required = 0
    for _, a in ipairs(st.assertions or {}) do
        if type(a) == "table" and not a.diagnostic then
            required = required + 1
            if a.absent then errs[#errs + 1] = w .. ": auto step cannot use a required absence check" end
        end
    end
    if hasA and required == 0 then errs[#errs + 1] = w .. ": auto step needs a required assertion" end
end

-- Returns a list of error strings (empty when valid).
function Plan.Validate(plan)
    local errs = {}
    if type(plan) ~= "table" then return { "plan is not a table" } end
    -- Text shown by the game is not Markdown: reject backticks and ** (use native color codes instead).
    local function md(s) return type(s) == "string" and (s:find("`", 1, true) or s:find("**", 1, true)) end
    local function checkText(box, key, where)
        if md(box[key]) then errs[#errs + 1] = "markdown in " .. where .. " " .. key .. ": use color codes, not backticks or **" end
    end
    checkText(plan, "title", "plan"); checkText(plan, "preamble", "plan"); checkText(plan, "handoff", "plan")
    if type(plan.requirements) == "table" then
        for name, def in pairs(plan.requirements) do
            if type(def) == "table" then checkText(def, "text", "requirement " .. tostring(name)) end
        end
    end
    for _, sec in ipairs(type(plan.sections) == "table" and plan.sections or {}) do
        if type(sec) == "table" then
            checkText(sec, "title", "section"); checkText(sec, "intro", "section"); checkText(sec, "setup", "section")
            for _, st in ipairs(type(sec.steps) == "table" and sec.steps or {}) do
                if type(st) == "table" then
                    local w = "step " .. tostring(st.id)
                    for _, k in ipairs({ "title", "setup", "expect", "notes", "reviewer" }) do checkText(st, k, w) end
                    if type(st.action) == "table" then checkText(st.action, "text", w) end
                    for _, a in ipairs(type(st.assertions) == "table" and st.assertions or {}) do
                        if type(a) == "table" then checkText(a, "label", w) end
                    end
                end
            end
        end
    end
    if plan.kind ~= "plan" then errs[#errs + 1] = "kind must be plan" end
    if plan.wtt ~= 1 then errs[#errs + 1] = "unsupported plan format version" end
    if not isStr(plan.addon) then errs[#errs + 1] = "addon missing" end
    if not isStr(plan.title) then errs[#errs + 1] = "title missing" end
    if isStr(plan.addon) and not Plan.SLASH[plan.addon] then
        errs[#errs + 1] = "addon not supported by this CheckThat version: " .. plan.addon
        return errs
    end
    local allow = Plan.SLASH[plan.addon] or {}
    local macros = {}
    for _, m in ipairs(plan.macros or {}) do
        if not (type(m) == "table" and isStr(m.id) and Plan.MacroAllowed(m.text, allow)) then
            errs[#errs + 1] = "macro not allowed: " .. tostring(type(m) == "table" and m.id)
        else macros[m.id] = true end
    end
    local reqs = plan.requirements or {}
    if type(plan.sections) ~= "table" or #plan.sections == 0 then errs[#errs + 1] = "no sections"; return errs end
    local seen = {}
    for _, sec in ipairs(plan.sections) do
        if type(sec) ~= "table" or type(sec.steps) ~= "table" then errs[#errs + 1] = "section without a steps list"; return errs end
        for _, st in ipairs(sec.steps) do
            if type(st) ~= "table" then errs[#errs + 1] = "step is not a table"; return errs end
            local w = "step " .. tostring(st.id)
            if not isStr(st.id) then errs[#errs + 1] = "step without id"
            elseif seen[st.id] then errs[#errs + 1] = "duplicate step id " .. st.id
            else seen[st.id] = true end
            if not isStr(st.title) then errs[#errs + 1] = w .. ": title missing" end
            if not isStr(st.expect) then errs[#errs + 1] = w .. ": expect missing" end
            for _, c in ipairs(st.clients or {}) do
                if not Plan.CLIENTS[c] then errs[#errs + 1] = w .. ": unknown client " .. tostring(c) end
            end
            for _, r in ipairs(st.requires or {}) do
                if not reqs[r] then errs[#errs + 1] = w .. ": unresolved requirement " .. tostring(r) end
            end
            local act = st.action
            if type(act) ~= "table" or not Plan.ACTIONS[act.kind] then
                errs[#errs + 1] = w .. ": unknown action kind " .. tostring(type(act) == "table" and act.kind)
            elseif act.kind == "secure-macro" and not macros[act.macro] then
                errs[#errs + 1] = w .. ": macro not in plan macros " .. tostring(act.macro)
            elseif act.kind == "copy-slash" and not Plan.MacroAllowed(act.text, allow) then
                errs[#errs + 1] = w .. ": slash text not allowed"
            end
            for _, c in ipairs(type(act) == "table" and act.commands or {}) do
                if not Plan.MacroAllowed(c, allow) then errs[#errs + 1] = w .. ": command not allowed: " .. tostring(c) end
            end
            if type(st.verify) ~= "table" or #st.verify == 0 then errs[#errs + 1] = w .. ": verify missing"
            else
                local hasA
                for _, v in ipairs(st.verify) do
                    if not Plan.VERIFY[v] then errs[#errs + 1] = w .. ": unknown verify " .. tostring(v) end
                    if v == "assertions" then hasA = true end
                end
                local hasR
                for _, v in ipairs(st.verify) do if v == "reviewer" then hasR = true end end
                if hasR and not isStr(st.reviewer) then errs[#errs + 1] = w .. ": verify reviewer but no reviewer text" end
                if hasA and not (st.assertions and #st.assertions > 0) then errs[#errs + 1] = w .. ": verify assertions but none given" end
                if not hasA and st.assertions and #st.assertions > 0 then errs[#errs + 1] = w .. ": assertions given but verify lacks assertions" end
            end
            for i, a in ipairs(st.assertions or {}) do checkAssertion(a, i, errs, plan.logs, w) end
            Plan.CheckAuto(st, w, errs)
            if st.share ~= nil and st.share ~= "none" and st.share ~= "reload" and st.share ~= "export" then errs[#errs + 1] = w .. ": bad share" end
            if st.screenshot ~= nil and type(st.screenshot) ~= "boolean" then errs[#errs + 1] = w .. ": screenshot must be boolean" end
            if st.reload ~= nil and st.reload ~= "none" and st.reload ~= "after_action" then errs[#errs + 1] = w .. ": bad reload" end
        end
    end
    return errs
end

-- Ordered steps applicable to a client, with the section title attached. Others come back in .skipped.
function Plan.Steps(plan, client)
    local steps, skipped = {}, {}
    for _, sec in ipairs(plan.sections) do
        for _, st in ipairs(sec.steps) do
            local ok = not st.clients or #st.clients == 0
            for _, c in ipairs(st.clients or {}) do if c == client then ok = true end end
            local entry = { step = st, section = sec.title, intro = sec.intro, sectionId = sec.id }
            if ok then steps[#steps + 1] = entry else skipped[#skipped + 1] = entry end
        end
    end
    return steps, skipped
end
