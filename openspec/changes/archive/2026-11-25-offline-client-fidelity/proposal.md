# Proposal

## Why

CheckThat's fake client does not know which game client it stands for, and offline runs give no sign of where it differs from the game (review of 2026-11-25). Every game call goes through a guarded Adapter, so a name the fake lacks becomes nil, and the run takes a branch the game never takes. `ct offline` answers as interface 11507 for every addon, which matches neither Classic Era (11509) nor WoW Forever (16001). LuaJIT accepts syntax that the game's Lua 5.1 rejects or reads differently, and addon code can reach `io`, `os` and `jit`. No offline data source lists every name the game has, so only the client itself can say. Issues #146, #147 and #148, plus the interface part of #145.

## What Changes

- **New `/ct census` (#146).** It records in the saved variables the global names and types that the game itself defines (`issecurevariable`), so another addon's globals and saved variables are left out. It also records the members of API namespaces and named public tables, and the methods of sample widget types. It changes no setting and calls no game action. It creates a few hidden sample frames, which disappear at reload. It refuses to start in combat, pauses while in combat, and works within a time budget for each frame. It keeps the newest census only, and replaces it only when a walk completes.
- **New `ct.py census`.** It writes one JSON manifest per build from the copied saved variables (`tests/manifests/<client>-<build>.json`). `--diff OLD NEW` shows added and removed names and type changes.
- **Offline runner reads the interface from the TOC (#145, first part).** `GetBuildInfo` answers with the TOC's `## Interface:` number.
- **Nil-read report (#147).** The runner records the globals that addon code read as nil. `ct.py offline` prints them, and splits them against the matching manifest when there is one. It prints the same text in JUnit `<system-out>`. The report is advisory: counts and exit codes do not change. `make test` compares CheckThat's own smoke load with a baseline file.
- **Lua 5.1 gate (#148).** One scanner checks every file that `make check` and `ct.py offline` load (TOC, XML and libraries). It fails on syntax the game rejects (`goto`, labels) and on code whose meaning changes (`\x`, `\z` and `\u{}` escapes, and the `LL`, `ULL` and `i` number suffixes). The runner hides `io`, `os`, `jit`, `ffi`, `require`, `package`, `loadfile` and `dofile` from addon code. `make check` also fails when CheckThat code reads one of them.
- **CTProbe** is kept in `tools/ctprobe/` so the measurements in `docs/contracts.md` can be repeated.

## Capabilities

### New Capabilities

- `client-census`: the in-game census and the manifests made from it.

### Modified Capabilities

- `offline-entry-runner`: interface from the TOC, the nil-read report, the Lua 5.1 gate and hidden globals.
- `slash-interface`: `/ct census`.

## Impact

- Addon: `CheckThat/Model/Census.lua` (new, in both TOCs), `Core/Adapter.lua`, `Core/Slash.lua`, `Core/Addon.lua`, `Locales/enUS.lua`. This is a new player-visible command, so it needs a minor version bump.
- Tools: `tools/entry_runner.lua`, `tools/lua51_check.lua` (new), `tools/ct.py`, `tests/harness.lua`, `Makefile`.
- Tests: `tests/test_census.lua`, `tests/test_lua51.lua`, `tests/test_divergence.lua`, `tests/test_entries.lua`, `tools/test_ct.py`.
- Docs: README, `docs/features.md`, `docs/authoring-plans.md`, `docs/test-plan.md`, `docs/contracts.md` and `docs/listing.md`.
