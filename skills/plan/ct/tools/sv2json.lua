-- luajit tools/sv2json.lua FILE.lua  -> JSON of every global the SavedVariables file defines.
local path = arg[1]
local here = arg[0]:match("^(.*)/tools/[^/]*$") or "."
local ns = {}
assert(loadfile(here .. "/CheckThat/Model/Json.lua"))("CheckThat", ns)

local env = {}
local chunk, err = loadfile(path)
if not chunk then io.stderr:write(err, "\n"); os.exit(1) end
setfenv(chunk, env)
local ok, e = pcall(chunk)
if not ok then io.stderr:write(tostring(e), "\n"); os.exit(1) end

local function norm(v, depth)
    if type(v) ~= "table" then
        if type(v) == "function" or type(v) == "userdata" then return nil end
        return v
    end
    if depth > 30 then return nil end
    local n, isArr = 0, true
    for _ in pairs(v) do n = n + 1 end
    for i = 1, n do if v[i] == nil then isArr = false; break end end
    local out = {}
    if isArr then
        for i = 1, n do out[i] = norm(v[i], depth + 1) end
    else
        for k, x in pairs(v) do out[tostring(k)] = norm(x, depth + 1) end
    end
    return out
end

local out = {}
for k, v in pairs(env) do out[k] = norm(v, 0) end
local s, jerr = ns.Json.Encode(out)
if not s then io.stderr:write(jerr, "\n"); os.exit(1) end
io.write(s, "\n")
