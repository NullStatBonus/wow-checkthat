# Proposal

## Why

`ct test` runs an addon against a fake CheckThat that has only `Entry`, `Report`, `API_VERSION = 2` and `PROTOTYPE`, set before the addon's first file loads (#285). The addons that integrate with CheckThat 1.0.0 also use `OnRun` and `ActiveRun`, so offline they always take their "CheckThat too old" path. A test also cannot call the entries the addon registered, read the facts it reported, open or end a run, or load the addon without CheckThat or before it. So `ct test` cannot check the addon's CheckThat integration, which is the code it is best placed to check.

## What Changes

- **`ct test` gets CheckThat's own public API.** The fake is the table the game gives (`CheckThat/Model/Facts.lua` `Facts.API()`: `API_VERSION` 4, `Entry`, `OnRun`, `ActiveRun`, `Commands`, `Report`) built from CheckThat's own `Facts`, `Entries` and `RunEvents` modules for each load, so it keeps the game's rules: `Report` records only while a run is open, `OnRun` gets `start` at once when a run is already open.
- **A `checkThat` option for `ct.test`:** `"early"` (the default: CheckThat is there before the addon's first file, as when the addon loads after it), `"late"` (CheckThat loads after the addon: the global appears after the addon's `ADDON_LOADED`, then `ADDON_LOADED("CheckThat")` fires before `VARIABLES_LOADED`), `"missing"` (no CheckThat).
- **New `ctx` fields** (additive): `ctx.entry(name, ...)` calls an entry the addon registered, `ctx.reports()` returns the facts recorded in this load, `ctx.run("start"|"end", info)` opens or ends a run for the addon. A run stays open across `ctx.reload()`.
- Docs: `docs/addon-tests.md`, the `ctx` table in `docs/authoring-plans.md`.

## Capabilities

### New Capabilities

### Modified Capabilities
- `offline-entry-runner`: `ct test` gets CheckThat's public API and a load-order option; the hook context gains `entry`, `reports` and `run`.

## Impact

Tools, tests and docs only. No file under `CheckThat/` changes, so no version bump. Offline blocks keep today's fake CheckThat and their results: the fuller fake is for `ct test` only. `ct.API` stays 1. Part of PR #283; closes #285.
