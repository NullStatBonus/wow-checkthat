-- Usage: luajit tools/dump_options.lua TOC
-- Loads an addon's TOC under the fake client (offline level 5: the client's real surface, the login events fired) and reads the
-- options tables the addon registered with AceConfigRegistry-3.0. Prints JSON: { "tables": N, "keys": [setting keys] }. A key is
-- the name of a node of an options tree that holds a value (toggle, range, select, multiselect, input, color or keybinding). Two
-- settings with the same name in different groups count once. An addon that registers its options later
-- (when its settings panel opens) leaves the registry empty: tables is 0 and ct.py coverage falls back to the source.
-- It runs the addon's Lua: use addons you trust.
local here = arg[0]:match("^(.*)/tools/[^/]*$") or "."
local Runner = dofile(here .. "/tools/entry_runner.lua")

local found = { tables = 0, keys = {} }
local VALUE = { toggle = true, range = true, select = true, multiselect = true, input = true, color = true, keybinding = true } -- not group, header, description or execute

local function walk(node, seen)
    if type(node) ~= "table" or seen[node] then return end
    seen[node] = true
    for key, child in pairs(type(node.args) == "table" and node.args or {}) do
        if type(child) == "table" then
            if child.type == "group" then walk(child, seen)
            elseif VALUE[child.type] then
                found.keys[tostring(key)] = true
            end
        end
    end
end

local function read(ns, st, n)
    local stub = rawget(_G, "LibStub")
    local reg = type(stub) == "table" and stub.GetLibrary and stub:GetLibrary("AceConfigRegistry-3.0", true)
    if type(reg) ~= "table" or type(reg.tables) ~= "table" then return end
    for name, tbl in pairs(reg.tables) do
        if type(tbl) == "function" then local ok, v = pcall(tbl, "dialog", "CoverageProbe-1.0", 1); tbl = ok and v or nil end
        if type(tbl) == "table" then found.tables = found.tables + 1; walk(tbl, {}) end
    end
end

local toc = arg[1]
if not toc then io.stderr:write("usage: luajit tools/dump_options.lua TOC\n"); os.exit(2) end
local result, Json = Runner.run({ toc = toc, level = 5, steps = {} }, { root = here, loaded = read })
if not result.ok then -- the addon did not load: say why and let ct.py fall back to the source
    local why = "the run failed"
    for _, s in ipairs(result.steps) do if not s.ok then why = tostring(s.detail); break end end
    io.stderr:write(why:gsub("\n.*", ""), "\n")
    os.exit(1)
end
local keys = {}
for k in pairs(found.keys) do keys[#keys + 1] = k end
table.sort(keys)
io.write(Json.Encode({ tables = found.tables, keys = keys }), "\n")
