-- Fixture addon: one AceConfig table, one helper call.
local options = { type = "group", args = {
    verbose = { type = "toggle", name = "Verbose" },
    size = { type = "range", name = "Size", min = 1, max = 9 },
    refresh = { type = "execute", name = "Refresh" },
} }
add(options.args, "quiet", { type = "toggle", name = "Quiet" })
