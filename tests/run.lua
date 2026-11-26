-- Usage (from the project root): luajit tests/run.lua [file-pattern [test-name]]
-- Runs every tests/test_*.lua whose name contains the optional pattern, each in its own
-- process so tests cannot leak state into each other. Prints failures in full, a summary,
-- and exits non-zero if anything failed.
local pattern = arg and arg[1]
local testName = arg and arg[2] -- passed to each file, which runs only tests whose name contains it
local NO_MATCH = 3 -- a file where testName matched no test (H.NO_MATCH)

local files = {}
local ls = io.popen("ls tests/test_*.lua 2>/dev/null")
for line in ls:lines() do
    if not pattern or line:find(pattern, 1, true) then files[#files + 1] = line end
end
ls:close()

if #files == 0 then
    print("no tests match" .. (pattern and (" '" .. pattern .. "'") or ""))
    os.exit(1)
end

local failed, skipped, ran = {}, 0, 0
for _, file in ipairs(files) do
    local arg2 = testName and (" '" .. testName:gsub("'", "'\\''") .. "'") or ""
    local p = io.popen("luajit " .. file .. arg2 .. " 2>&1; echo EXIT:$?")
    local out = p:read("*a")
    p:close()
    local code = tonumber(out:match("EXIT:(%d+)%s*$"))
    out = out:gsub("EXIT:%d+%s*$", ""):gsub("%s+$", "")
    local name = file:match("[^/]+$")
    if code == NO_MATCH then
        skipped = skipped + 1
    elseif code == 0 then
        ran = ran + 1
        print(("ok    %-24s %s"):format(name, out:match("[^\n]*$")))
    else
        print(("FAIL  %s"):format(name))
        print((out:gsub("[^\n]*\n?", "      %0")))
        failed[#failed + 1] = name
    end
end

if testName and ran == 0 and #failed == 0 then
    print(("no test matches '%s'"):format(testName))
    os.exit(1)
end
print(("\n%d test file(s), %d failed%s"):format(#files - skipped, #failed, skipped > 0 and (", %d skipped (no matching test)"):format(skipped) or ""))
os.exit(#failed == 0 and 0 or 1)
