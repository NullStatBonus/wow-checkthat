-- Builds the event manifest of one game client from Blizzard's UI source (Gethe/wow-ui-source):
--
--   luajit tools/events_manifest.lua SOURCE_DIR CLIENT INTERFACE > tools/events/CLIENT.json
--
-- SOURCE_DIR is a checkout of one wow-ui-source track (classic_era, forever). The manifest lists every event the
-- generated API documentation names, with the number of payload values and how many of them are not nilable, and
-- every event Blizzard's own code registers that the documentation omits (payload unknown). The offline runner reads
-- it at level 4. Each documentation file is data: it runs with an environment that holds only the collector.
local here = arg[0]:match("^(.*)/tools/[^/]*$") or "."
local src, client, interface = arg[1], arg[2], tonumber(arg[3])
if not (src and client and interface) then io.stderr:write("usage: events_manifest.lua SOURCE_DIR CLIENT INTERFACE\n"); os.exit(2) end
local ns = {}
assert(loadfile(here .. "/CheckThat/Model/Json.lua"))("CheckThat", ns)

local function lines(cmd)
    local p = assert(io.popen(cmd)); local out = {}
    for l in p:lines() do out[#out + 1] = l end
    p:close(); return out
end
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

local events, documented = {}, 0
local docDir = src .. "/Interface/AddOns/Blizzard_APIDocumentationGenerated"
for _, file in ipairs(lines("ls " .. q(docDir) .. "/*.lua")) do
    local chunk = assert(loadfile(file))
    local tables = {}
    setfenv(chunk, { APIDocumentation = { AddDocumentationTable = function(_, t) tables[#tables + 1] = t end } })
    if pcall(chunk) then
        for _, t in ipairs(tables) do
            for _, e in ipairs(t.Events or {}) do
                if e.LiteralName and not events[e.LiteralName] then
                    local payload, required = 0, 0
                    for _, p in ipairs(e.Payload or {}) do
                        payload = payload + 1
                        if not p.Nilable then required = payload end
                    end
                    events[e.LiteralName] = { payload = payload, required = required }
                    documented = documented + 1
                end
            end
        end
    end
end
-- Events Blizzard code registers that the documentation does not name.
local extra = 0
for _, l in ipairs(lines("grep -rhoE 'Register(Unit)?Event\\(\"[A-Z0-9_]+\"' " .. q(src .. "/Interface") .. " | sort -u")) do
    local n = l:match('"([A-Z0-9_]+)"')
    if n and not events[n] then events[n] = { documented = false }; extra = extra + 1 end
end
local version = (io.open(src .. "/version.txt") or io.open("/dev/null")):read("*l") or ""
local major, build = version:match("^(%S+)%s*%((%d+)%)")
local commit = (lines("git -C " .. q(src) .. " rev-parse HEAD 2>/dev/null")[1]) or "unknown"
io.stderr:write(("%d documented events, %d more from Blizzard code\n"):format(documented, extra))
-- One event per line, sorted, so a new build's list diffs cleanly.
local J = ns.Json.Encode
local head = { format = 1, client = client, build = major and (major .. "." .. build) or version, interface = interface,
    source = "Gethe/wow-ui-source " .. commit }
local out = { "{" }
for _, k in ipairs({ "format", "client", "build", "interface", "source" }) do out[#out + 1] = ("  %s: %s,"):format(J(k), J(head[k])) end
out[#out + 1] = '  "events": {'
local names = {}
for n in pairs(events) do names[#names + 1] = n end
table.sort(names)
for i, n in ipairs(names) do
    local e = events[n]
    local v = e.documented == false and '{"documented": false}' or ('{"payload": %d, "required": %d}'):format(e.payload, e.required)
    out[#out + 1] = ("    %s: %s%s"):format(J(n), v, i < #names and "," or "")
end
out[#out + 1] = "  }"
out[#out + 1] = "}"
io.write(table.concat(out, "\n"), "\n")
