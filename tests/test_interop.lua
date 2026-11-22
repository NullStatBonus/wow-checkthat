local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
-- Strings compiled by tools/wtt.py (make build) must decode and validate in the addon.
local names = { "keepthat", "dontdothat", "closestvendor", "selftest" }
for _, n in ipairs(names) do
    test("interop: python-compiled " .. n .. " decodes and validates in Lua", function()
        local f = io.open("build/" .. n .. ".wtt")
        T.ok(f, "build/" .. n .. ".wtt missing (run make build)")
        local s = f:read("*a"); f:close()
        local plan, err = ns.Codec.Decode(s)
        T.ok(plan, err)
        local errs = ns.Plan.Validate(plan)
        T.eq(#errs, 0, table.concat(errs, "; "):sub(1, 400))
        -- and Lua re-encodes to something Lua decodes to the same table
        local again = assert(ns.Codec.Decode(assert(ns.Codec.Encode(plan))))
        T.ok(T.deepEq(plan, again), "re-encode round trip")
    end)
end
finish()
