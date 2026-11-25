-- Fixture addon for tools/test_ct.py (ct.py coverage): three subcommands.
local function handle(cmd, rest)
    if cmd == "alpha" then return "a"
    elseif cmd == "beta" then return "b"
    elseif cmd == "gamma" then return "g"
    end
end
