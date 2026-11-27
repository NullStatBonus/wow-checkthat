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
Plan.OPS = { eq = true, ne = true, gt = true, ge = true, lt = true, le = true, contains = true, exists = true, missing = true,
    between = true, approx = true, matches = true, type = true, ["in"] = true }
Plan.TYPES = { number = true, boolean = true, string = true }
Plan.WHICH = { last = true, any = true, all = true }
Plan.ID = "^[a-z0-9][a-z0-9._-]*$"
Plan.BUILTIN_SLASH = { ["/reload"] = true, ["/reloadui"] = true, ["/console"] = true }
-- Class tokens a requirement may name (the second value of UnitClass).
Plan.CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, DEATHKNIGHT = true, SHAMAN = true,
    MAGE = true, WARLOCK = true, MONK = true, DRUID = true, DEMONHUNTER = true, EVOKER = true }
Plan.LIST_MIN, Plan.LIST_MAX = 2, 6 -- items in a list of actions or results

local function isStr(v) return type(v) == "string" and v ~= "" end
local function isNum(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function isCount(v) return isNum(v) and v % 1 == 0 and v >= 0 and v <= 1000 end

-- Nil when v is absent or text; else the error.
local function textField(errs, where, name, v)
    if v ~= nil and type(v) ~= "string" then errs[#errs + 1] = where .. ": " .. name .. " must be text" end
end
local function listField(errs, where, name, v)
    if v ~= nil and type(v) ~= "table" then errs[#errs + 1] = where .. ": " .. name .. " must be a list" end
end
-- One of equals, contains or pattern, as text, and a pattern the game can match in good time.
local function checkMatcher(m, errs, where, what)
    if type(m) ~= "table" then errs[#errs + 1] = where .. ": " .. what .. " not a table"; return end
    local n = 0
    for _, k in ipairs({ "equals", "contains", "pattern" }) do
        if m[k] ~= nil then
            n = n + 1
            if type(m[k]) ~= "string" then errs[#errs + 1] = where .. ": " .. what .. " " .. k .. " must be text" end
        end
    end
    if n ~= 1 then
        errs[#errs + 1] = where .. ": " .. what .. " needs exactly one of equals, contains, pattern"
    end
    if type(m.pattern) == "string" then
        local why = Plan.PatternProblem(m.pattern)
        if why then errs[#errs + 1] = where .. ": " .. why end
    end
end

-- Action text and expect are one sentence or a list of them. Lines gives the list (a string is one line), Join one string.
function Plan.Lines(v)
    if type(v) == "table" then return v end
    if v == nil then return {} end
    return { v }
end
function Plan.Join(v) return type(v) == "table" and table.concat(v, " ") or v end
-- Nil when v is a sentence or a list of 2 to 6 sentences, else why not.
local function textOrList(v)
    if isStr(v) then return nil end
    if type(v) ~= "table" then return "must be text or a list" end
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    if n ~= #v then return "must be a list" end
    if n == 1 then return "is a list of one: write it as text" end
    if n < Plan.LIST_MIN or n > Plan.LIST_MAX then return ("is a list of %d: give %d to %d items"):format(n, Plan.LIST_MIN, Plan.LIST_MAX) end
    for _, s in ipairs(v) do if not isStr(s) then return "has an item that is not text" end end
    return nil
end

-- A plan pattern is a Lua 5.1 pattern of up to PATTERN_MAX characters. string.find raises on a malformed one, so a pattern that
-- Lua cannot read is refused (Plan.PatternProblem); Pattern.lua runs the rest with a step budget. tools/ct.py pattern_problem
-- mirrors this, reason text included; tests/fixtures/parity-patterns.json holds the cases both read.
Plan.PATTERN_MAX = 200

-- p:sub(i, i) is "[": the index after the closing "]" of the set, or nil when it is missing. Like Lua, a "]" first is a member.
local function setEnd(p, i)
    local n = #p
    i = i + 1
    if p:sub(i, i) == "^" then i = i + 1 end
    repeat
        if i > n then return nil end
        local c = p:sub(i, i)
        i = i + 1
        if c == "%" and i <= n then i = i + 1 end
    until p:sub(i, i) == "]"
    return i + 1
end

-- Why Lua would raise on this pattern, or nil. The same items Lua reads: captures, %b, %f, back references, sets, escapes.
local function patternError(p)
    if not p:find("[%^%$%*%+%?%.%(%[%%%-]") then return nil end -- no special character: string.find searches for the text, whatever it is
    local n, i = #p, 1
    local caps, closed, stack = 0, {}, {}
    if p:sub(1, 1) == "^" then i = 2 end
    while i <= n do
        local c = p:sub(i, i)
        local last
        if c == "(" then
            if caps >= 32 then return "pattern has too many captures" end
            caps = caps + 1; closed[caps] = false; stack[#stack + 1] = caps
            i = i + 1
        elseif c == ")" then
            if #stack == 0 then return "pattern closes a capture it did not open" end
            closed[stack[#stack]] = true; stack[#stack] = nil
            i = i + 1
        elseif c == "$" and i == n then i = i + 1
        elseif c == "%" then
            local d = p:sub(i + 1, i + 1)
            if d == "" then return "pattern ends with a lone %" end
            if d == "b" then
                if i + 3 > n then return "pattern has %b without its two characters" end
                i = i + 4
            elseif d == "f" then
                if p:sub(i + 2, i + 2) ~= "[" then return "pattern has %f without a set after it" end
                local e = setEnd(p, i + 2)
                if not e then return "pattern has a set with no closing ]" end
                i = e
            elseif d:find("^%d$") then
                local k = tonumber(d)
                if k == 0 or k > caps or not closed[k] then return "pattern names a capture that is not closed" end
                i = i + 2
            else last = i + 1 end
        elseif c == "[" then
            local e = setEnd(p, i)
            if not e then return "pattern has a set with no closing ]" end
            last = e - 1
        else last = i end
        if last then
            local q = p:sub(last + 1, last + 1)
            if q == "*" or q == "+" or q == "-" or q == "?" then last = last + 1 end
            i = last + 1
        end
    end
    if #stack > 0 then return "pattern opens a capture it does not close" end
    return nil
end

local patternCache = {}
-- Nil when this is a pattern string.find can run, else why not (an English phrase starting with "pattern").
function Plan.PatternProblem(p)
    if type(p) ~= "string" then return "pattern must be text" end
    local hit = patternCache[p]
    if hit == nil then
        if #p > Plan.PATTERN_MAX then hit = ("pattern is longer than %d characters"):format(Plan.PATTERN_MAX)
        elseif p:find("\0", 1, true) then hit = "pattern has a NUL byte; write %z" -- Lua 5.1 ends a pattern at a NUL
        else hit = patternError(p) or (not pcall(string.find, "a", p) and "pattern is not valid") or false end
        patternCache[p] = hit
    end
    return hit or nil
end

-- An operator needs a value of the right shape. Older operators keep their loose rules so saved plans stay valid.
local function checkOp(a, errs, where)
    local op, v = a.op, a.value
    if not Plan.OPS[op] then errs[#errs + 1] = where .. ": unknown op " .. tostring(op); return end
    if op == "between" then
        if not (type(v) == "table" and #v == 2 and isNum(v[1]) and isNum(v[2]) and v[1] <= v[2]) then
            errs[#errs + 1] = where .. ": between needs a value of two numbers, low then high"
        end
    elseif op == "in" then
        if not (type(v) == "table" and #v > 0) then errs[#errs + 1] = where .. ": in needs a value that is a list" end
    elseif op == "approx" then
        if not isNum(v) then errs[#errs + 1] = where .. ": approx needs a number value" end
        if not (isNum(a.tolerance) and a.tolerance >= 0) then errs[#errs + 1] = where .. ": approx needs a tolerance of zero or more" end
    elseif op == "type" then
        if not Plan.TYPES[v] then errs[#errs + 1] = where .. ": type needs number, boolean or string" end
    elseif op == "matches" then
        if not (isStr(v) and #v <= 200) then errs[#errs + 1] = where .. ": matches needs a pattern of up to 200 characters"
        else
            local why = Plan.PatternProblem(v)
            if why then errs[#errs + 1] = where .. ": matches " .. why end
        end
    elseif op == "ge" or op == "le" then
        if not isNum(v) then errs[#errs + 1] = where .. ": " .. op .. " needs a number value" end
    end
    if a.tolerance ~= nil and op ~= "approx" then errs[#errs + 1] = where .. ": tolerance belongs to approx" end
end

local function checkCount(a, errs, where)
    local c = a.count
    if c == nil then return end
    if type(c) ~= "table" then errs[#errs + 1] = where .. ": count must be a table"; return end
    local n = 0
    for k, v in pairs(c) do
        if k ~= "exactly" and k ~= "min" and k ~= "max" then errs[#errs + 1] = where .. ": unknown count field " .. tostring(k)
        else
            n = n + 1
            if not isCount(v) then errs[#errs + 1] = where .. ": count " .. k .. " must be a whole number from 0 to 1000" end
        end
    end
    if n == 0 then errs[#errs + 1] = where .. ": count needs exactly, min or max" end
    if c.exactly ~= nil and (c.min ~= nil or c.max ~= nil) then errs[#errs + 1] = where .. ": count exactly cannot combine with min or max" end
    if isNum(c.min) and isNum(c.max) and c.min > c.max then errs[#errs + 1] = where .. ": count min is above max" end
    if a.absent then errs[#errs + 1] = where .. ": count cannot combine with absent" end
end

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
    textField(errs, where, "label", a.label)
    for _, flag in ipairs({ "diagnostic", "absent" }) do
        if a[flag] ~= nil and type(a[flag]) ~= "boolean" then errs[#errs + 1] = where .. ": " .. flag .. " must be boolean" end
    end
    if a.kind == "log" then
        if not (logs and logs[a.source]) then errs[#errs + 1] = where .. ": unknown log source " .. tostring(a.source) end
        checkMatcher(a, errs, where, "log assertion")
        if a.scope ~= nil and a.scope ~= "attempt" and a.scope ~= "run" and a.scope ~= "session" then errs[#errs + 1] = where .. ": bad scope" end
        checkCount(a, errs, where)
    elseif a.kind == "fact" then
        if not (logs and logs[a.source]) then errs[#errs + 1] = where .. ": unknown log source " .. tostring(a.source) end
        if not isStr(a.addon) then errs[#errs + 1] = where .. ": fact needs an addon" end
        if not isStr(a.key) then errs[#errs + 1] = where .. ": fact needs a key" end
        if a.which ~= nil and not Plan.WHICH[a.which] then errs[#errs + 1] = where .. ": which must be last, any or all" end
        if a.scope ~= nil and a.scope ~= "attempt" and a.scope ~= "run" and a.scope ~= "session" then errs[#errs + 1] = where .. ": bad scope" end
        checkOp(a, errs, where)
        checkCount(a, errs, where)
    elseif a.kind == "log-sequence" then
        if a.count ~= nil then errs[#errs + 1] = where .. ": count does not apply to log-sequence" end
        if not (logs and logs[a.source]) then errs[#errs + 1] = where .. ": unknown log source " .. tostring(a.source) end
        if type(a.sequence) ~= "table" or #a.sequence == 0 then errs[#errs + 1] = where .. ": empty sequence" end
        for _, m in ipairs(type(a.sequence) == "table" and a.sequence or {}) do checkMatcher(m, errs, where, "sequence item") end
    elseif a.kind == "state" then
        if not Plan.PROBES[a.probe] then errs[#errs + 1] = where .. ": unknown probe " .. tostring(a.probe) end
        if a.count ~= nil then errs[#errs + 1] = where .. ": count does not apply to state" end
        checkOp(a, errs, where)
    else errs[#errs + 1] = where .. ": unknown assertion kind " .. tostring(a.kind) end
end

-- An auto step is settled by its own evidence, so the evidence must be able to settle it alone.
function Plan.CheckAuto(st, w, errs)
    if st.auto ~= nil and type(st.auto) ~= "boolean" then errs[#errs + 1] = w .. ": auto must be boolean" end
    local isAuto = st.auto == true
    local act = st.action
    if type(act) == "table" and act.kind == "wait-event" and not isAuto then errs[#errs + 1] = w .. ": wait-event needs an auto step" end
    if st.call ~= nil then
        local c = st.call
        if not isAuto then errs[#errs + 1] = w .. ": call needs auto"
        elseif type(c) ~= "table" or not (type(c.addon) == "string" and type(c.entry) == "string") then
            errs[#errs + 1] = w .. ": call needs addon and entry text"
        elseif #c.addon < 1 or #c.addon > 32 or c.addon:find("[^%w_%-]") or #c.entry < 1 or #c.entry > 42 or c.entry:find("[^%w_%.%-]") then
            errs[#errs + 1] = w .. ": call addon is 1 to 32 letters, digits, _ or -, and entry is 1 to 42 of the same plus ."
        else
            for k in pairs(c) do
                if k ~= "addon" and k ~= "entry" and k ~= "args" then errs[#errs + 1] = w .. ": call has unknown field " .. tostring(k) end
            end
            local nargs = 0
            if c.args ~= nil and type(c.args) ~= "table" then errs[#errs + 1] = w .. ": call args must be a list of at most 8"
            elseif c.args ~= nil then
                for _ in pairs(c.args) do nargs = nargs + 1 end
                if nargs ~= #c.args or nargs > 8 then errs[#errs + 1] = w .. ": call args must be a list of at most 8"
                else
                    for i, v in ipairs(c.args) do
                        local tv = type(v)
                        if tv ~= "string" and tv ~= "number" and tv ~= "boolean" then errs[#errs + 1] = w .. ": call arg " .. i .. " must be text, a number or true or false" end
                    end
                end
            end
        end
    end
    local t = st.timeout
    if t ~= nil then
        if not isAuto then errs[#errs + 1] = w .. ": timeout needs auto"
        elseif type(t) ~= "number" or t % 1 ~= 0 or t < 5 or t > 300 then
            errs[#errs + 1] = w .. ": timeout must be a whole number from 5 to 300"
        end
    end
    if st.async ~= nil then
        if type(st.async) ~= "boolean" then errs[#errs + 1] = w .. ": async must be boolean"
        elseif st.async then
            if not isAuto then errs[#errs + 1] = w .. ": async needs auto" end
            if st.setup ~= nil or st.call ~= nil or st.reload == "after_action" then
                errs[#errs + 1] = w .. ": async cannot have setup, a call or a reload: it is judged before the player does anything"
            end
        end
    end
    if not isAuto then return end
    local hasA, hasP
    for _, v in ipairs(type(st.verify) == "table" and st.verify or {}) do
        if v == "assertions" then hasA = true elseif v == "player" then hasP = true end
    end
    if not hasA then errs[#errs + 1] = w .. ": auto step needs assertions in verify" end
    if hasP then errs[#errs + 1] = w .. ": auto step cannot ask the player" end
    -- A check that something did not happen (an absence, a missing fact, a count of exactly or at most n) cannot be
    -- shown the moment it holds, as more can arrive. It is judged when the timeout ends, so the step needs one.
    local required, timed = 0, 0
    for _, a in ipairs(type(st.assertions) == "table" and st.assertions or {}) do
        if type(a) == "table" and not a.diagnostic then
            required = required + 1
            if a.absent or (a.kind == "fact" and a.op == "missing")
                or (type(a.count) == "table" and (a.count.exactly ~= nil or a.count.max ~= nil)) then timed = timed + 1 end
        end
    end
    if hasA and required == 0 then errs[#errs + 1] = w .. ": auto step needs a required assertion" end
    if timed > 0 and st.async then
        errs[#errs + 1] = w .. ": async cannot check that something did not happen (absence, missing, exactly or max): that needs a time window"
    end
    if timed > 0 and st.timeout == nil then
        errs[#errs + 1] = w .. ": auto step needs a timeout for a check that is judged at the end (absence, missing, exactly or max)"
    end
end

-- Returns a list of error strings (empty when valid).
function Plan.Validate(plan)
    local errs = {}
    if type(plan) ~= "table" then return { "plan is not a table" } end
    -- Text shown by the game is not Markdown: reject backticks and ** (use native color codes instead).
    local function md(s) return type(s) == "string" and (s:find("`", 1, true) or s:find("**", 1, true)) end
    local function checkText(box, key, where)
        local v = box[key]
        local any = md(v)
        if type(v) == "table" then for _, s in ipairs(v) do any = any or md(s) end end
        if any then errs[#errs + 1] = "markdown in " .. where .. " " .. key .. ": use color codes, not backticks or **" end
    end
    checkText(plan, "title", "plan"); checkText(plan, "preamble", "plan"); checkText(plan, "handoff", "plan")
    -- The card and the evidence code index these and call text methods on them, so a wrong type is refused here, not met on every refresh.
    textField(errs, "plan", "preamble", plan.preamble); textField(errs, "plan", "handoff", plan.handoff)
    listField(errs, "plan", "macros", plan.macros)
    if plan.requirements ~= nil and type(plan.requirements) ~= "table" then errs[#errs + 1] = "requirements must be a table" end
    if plan.logs ~= nil and type(plan.logs) ~= "table" then errs[#errs + 1] = "logs must be a table" end
    if type(plan.requirements) == "table" then
        for name, def in pairs(plan.requirements) do
            if type(def) ~= "table" then errs[#errs + 1] = "requirement " .. tostring(name) .. " must be a table"
            else
                local w = "requirement " .. tostring(name)
                checkText(def, "text", w)
                textField(errs, w, "text", def.text)
                if def.class ~= nil then
                    if type(def.class) ~= "table" or #def.class == 0 then errs[#errs + 1] = w .. ": class must be a list of class tokens"
                    else for _, c in ipairs(def.class) do if not Plan.CLASSES[c] then errs[#errs + 1] = w .. ": unknown class " .. tostring(c) end end end
                end
                if def.profession ~= nil then
                    local ok = type(def.profession) == "table" and #def.profession > 0
                    for _, p in ipairs(ok and def.profession or {}) do ok = ok and isStr(p) end
                    if not ok then errs[#errs + 1] = w .. ": profession must be a list of names" end
                end
                if def.unmet ~= nil and def.unmet ~= "blocked" and def.unmet ~= "inapplicable" then errs[#errs + 1] = w .. ": unmet must be blocked or inapplicable" end
                if def.unmet ~= nil and def.probe == nil and def.class == nil and def.profession == nil then
                    errs[#errs + 1] = w .. ": unmet needs a probe, class or profession"
                end
            end
        end
    end
    for _, sec in ipairs(type(plan.sections) == "table" and plan.sections or {}) do
        if type(sec) == "table" then
            checkText(sec, "title", "section"); checkText(sec, "intro", "section"); checkText(sec, "setup", "section")
            for _, k in ipairs({ "title", "intro", "setup" }) do textField(errs, "section " .. tostring(sec.id), k, sec[k]) end
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
    for name, src in pairs(type(plan.logs) == "table" and plan.logs or {}) do
        if type(src) ~= "table" then errs[#errs + 1] = "log source " .. tostring(name) .. " must be a table"
        else
            textField(errs, "log source " .. tostring(name), "global", src.global)
            textField(errs, "log source " .. tostring(name), "path", src.path)
        end
        if type(src) == "table" and src.quiet ~= nil and type(src.quiet) ~= "boolean" then errs[#errs + 1] = "log source " .. tostring(name) .. ": quiet must be boolean" end
        if type(src) == "table" and src.cap ~= nil and not (isNum(src.cap) and src.cap % 1 == 0 and src.cap >= 1 and src.cap <= 100000) then
            errs[#errs + 1] = "log source " .. tostring(name) .. ": cap must be a whole number from 1 to 100000"
        end
    end
    local declared, cats = type(plan.categories) == "table" and #plan.categories > 0, {}
    if plan.categories ~= nil and not declared then errs[#errs + 1] = "categories must be a non-empty list" end
    for _, c in ipairs(declared and plan.categories or {}) do
        if type(c) ~= "table" or not (isStr(c.id) and c.id:match(Plan.ID)) then errs[#errs + 1] = "category id is not valid"
        elseif c.id:lower() == "failed" then errs[#errs + 1] = "category id failed is reserved for /ct rerun failed"
        elseif cats[c.id] then errs[#errs + 1] = "duplicate category id " .. c.id
        else
            cats[c.id] = true
            if not isStr(c.title) then errs[#errs + 1] = "category " .. c.id .. ": title missing" end
            checkText(c, "title", "category " .. c.id); checkText(c, "intro", "category " .. c.id)
        end
    end
    if plan.kind ~= "plan" then errs[#errs + 1] = "kind must be plan" end
    if plan.ct ~= 1 then errs[#errs + 1] = "unsupported plan format version" end
    if not isStr(plan.addon) then errs[#errs + 1] = "addon missing" end
    if not isStr(plan.title) then errs[#errs + 1] = "title missing" end
    if isStr(plan.addon) and not Plan.SLASH[plan.addon] then
        errs[#errs + 1] = "addon not supported by this CheckThat version: " .. plan.addon
        return errs
    end
    local allow = Plan.SLASH[plan.addon] or {}
    local macros = {}
    for _, m in ipairs(type(plan.macros) == "table" and plan.macros or {}) do
        if not (type(m) == "table" and isStr(m.id) and Plan.MacroAllowed(m.text, allow)) then
            errs[#errs + 1] = "macro not allowed: " .. tostring(type(m) == "table" and m.id)
        else macros[m.id] = true end
    end
    local reqs = plan.requirements or {}
    if type(plan.sections) ~= "table" or #plan.sections == 0 then errs[#errs + 1] = "no sections"; return errs end
    local seen, secIds = {}, {}
    for _, sec in ipairs(plan.sections) do
        if type(sec) ~= "table" or type(sec.steps) ~= "table" then errs[#errs + 1] = "section without a steps list"; return errs end
        if not isStr(sec.id) then errs[#errs + 1] = "section without an id"
        elseif isStr(sec.id) and sec.id:lower() == "failed" and not declared then errs[#errs + 1] = "section id failed is reserved for /ct rerun failed (each section is a category)"
        elseif secIds[sec.id] then errs[#errs + 1] = "duplicate section id " .. sec.id
        elseif not sec.id:match(Plan.ID) then errs[#errs + 1] = "section id is not valid"
        else secIds[sec.id] = true end
        if sec.category ~= nil and not cats[sec.category] then errs[#errs + 1] = "section " .. tostring(sec.id) .. ": unknown category " .. tostring(sec.category) end
        for _, st in ipairs(sec.steps) do
            if type(st) ~= "table" then errs[#errs + 1] = "step is not a table"; return errs end
            local w = "step " .. tostring(st.id)
            textField(errs, w, "setup", st.setup)
            for _, k in ipairs({ "requires", "clients", "assertions" }) do listField(errs, w, k, st[k]) end
            if type(st.action) == "table" then listField(errs, w, "commands", st.action.commands) end
            if not isStr(st.id) then errs[#errs + 1] = "step without id"
            elseif not st.id:match(Plan.ID) then errs[#errs + 1] = "step id is not valid"
            elseif seen[st.id] then errs[#errs + 1] = "duplicate step id " .. st.id
            else seen[st.id] = true end
            if not isStr(st.title) then errs[#errs + 1] = w .. ": title missing" end
            if st.cases ~= nil then errs[#errs + 1] = w .. ": cases must be expanded when the plan compiles" end
            if st.category ~= nil and not cats[st.category] then errs[#errs + 1] = w .. ": unknown category " .. tostring(st.category)
            elseif declared and st.category == nil and sec.category == nil then errs[#errs + 1] = w .. ": no category (the plan declares categories)" end
            if st.expect == nil then errs[#errs + 1] = w .. ": expect missing"
            else local why = textOrList(st.expect); if why then errs[#errs + 1] = w .. ": expect " .. why end end
            if type(st.action) == "table" and st.action.text ~= nil then
                local why = textOrList(st.action.text)
                if why then errs[#errs + 1] = w .. ": action text " .. why end
            end
            for _, c in ipairs(type(st.clients) == "table" and st.clients or {}) do
                if not Plan.CLIENTS[c] then errs[#errs + 1] = w .. ": unknown client " .. tostring(c) end
            end
            for _, r in ipairs(type(st.requires) == "table" and st.requires or {}) do
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
            for _, c in ipairs(type(act) == "table" and type(act.commands) == "table" and act.commands or {}) do
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
            for i, a in ipairs(type(st.assertions) == "table" and st.assertions or {}) do checkAssertion(a, i, errs, plan.logs, w) end
            Plan.CheckAuto(st, w, errs)
            if st.share ~= nil and st.share ~= "none" and st.share ~= "reload" and st.share ~= "export" then errs[#errs + 1] = w .. ": bad share" end
            if st.screenshot ~= nil and type(st.screenshot) ~= "boolean" then errs[#errs + 1] = w .. ": screenshot must be boolean" end
            if st.reload ~= nil and st.reload ~= "none" and st.reload ~= "after_action" then errs[#errs + 1] = w .. ": bad reload" end
        end
    end
    return errs
end

-- The categories of a plan in order: those it declares, else one per section. Second result: true when declared.
function Plan.Categories(plan)
    if type(plan.categories) == "table" and #plan.categories > 0 then return plan.categories, true end
    local out = {}
    for _, sec in ipairs(plan.sections or {}) do out[#out + 1] = { id = sec.id, title = sec.title, intro = sec.intro } end
    return out, false
end

-- Ordered steps applicable to a client, with the section title attached. Others come back in .skipped.
function Plan.Steps(plan, client)
    local steps, skipped = {}, {}
    local declared = type(plan.categories) == "table" and #plan.categories > 0
    for _, sec in ipairs(plan.sections) do
        for _, st in ipairs(sec.steps) do
            local ok = not st.clients or #st.clients == 0
            for _, c in ipairs(st.clients or {}) do if c == client then ok = true end end
            local entry = { step = st, section = sec.title, intro = sec.intro, sectionId = sec.id,
                category = st.category or sec.category or (not declared and sec.id or nil) }
            if ok then steps[#steps + 1] = entry else skipped[#skipped + 1] = entry end
        end
    end
    return steps, skipped
end
