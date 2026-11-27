## Context

`SlashOwner` passes every unit test and the in-game check still missed `/ctp`. The client gives no way to see why from saved variables, so this change adds the evidence first.

## Decisions

- **Evidence before a guess.** Possible causes: a key in `SlashCmdList` whose read raised inside the single `pcall` (which then hid every key), `rawget` missing a name the client serves another way, or `issecurevariable` naming no owner. The rewrite removes the first two and the log line tells which remains.
- **A real-widget check.** The stub AceGUI in `test_layers.lua` cannot catch a missing method. The new test scans the AceGUI functions of `Export.lua` for `w:`, `dd:` and `edit:` calls and looks each one up in the shipped widget files and the AceGUI base.

## Non-Goals

- A fallback that offers `/ctp` without the game check. An addon can already declare its commands with `CheckThat.Commands`.
