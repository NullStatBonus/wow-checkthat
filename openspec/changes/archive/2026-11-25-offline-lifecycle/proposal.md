# Proposal

## Why

The offline runner loads an addon once and runs every step against that load (review of 2026-11-25, #149 and #107). It never assigns saved variables, so code that writes its database at file scope looks right offline and loses that write in the game. It fires no ADDON_LOADED, PLAYER_LOGIN or PLAYER_ENTERING_WORLD, and `IsLoggedIn()` is always true. It has no `/reload`, so a plan cannot show that state survives one. A step that changes state also changes every later step, so two cases that need opposite mocks cannot share a block.

## What Changes

- **Offline level 3: the game's load order (#149).** The runner reads `## SavedVariables` and `## SavedVariablesPerCharacter` from the TOC. Those names are nil while the files run. Then it assigns the values from the block's `savedVariables` (`## LoadSavedVariablesFirst: 1` assigns them before the files) and fires ADDON_LOADED with the folder name, PLAYER_LOGIN and PLAYER_ENTERING_WORLD (true, false). `IsLoggedIn()` is false until PLAYER_LOGIN.
- **`reload` step (#149).** It fires PLAYER_LEAVING_WORLD, PLAYER_LOGOUT and ADDONS_UNLOADING, and keeps a copy of each saved variable as the game writes it. Only strings, numbers, booleans and tables are kept, and two references to one table come back as two tables. Then it loads the addon fresh: every global the addon set and every upvalue is gone. It assigns the copies and fires the login events with PLAYER_ENTERING_WORLD (false, true).
- **`groups` (#107).** A block can hold groups in place of `steps`. Each group has its own steps, mocks and saved variables, and gets a fresh load of the addon.
- One fresh-load helper in `tests/harness.lua` puts the global table and the standard library tables back as they were before the first load, for both reload and groups. CheckThat's own test of a run surviving a reload uses it too.
- `reload`, `groups` and `savedVariables` need `level: 3`. A block at level 1 or 2 keeps its result.

## Capabilities

### Modified Capabilities

- `offline-entry-runner`: level 3, the reload step, groups and the fresh load.
- `test-plan-format`: the offline block gains `savedVariables`, `groups` and the `reload` step, and `level` accepts 3.

## Impact

- Tools: `tools/entry_runner.lua`, `tests/harness.lua`, `tools/ct.py`, `schema/test-plan.schema.json`.
- Tests: `tests/test_entries.lua`, `tests/test_lifecycle.lua` (new), new MockAddon fixtures, `tools/test_ct.py`.
- Docs: `docs/authoring-plans.md`, `skills/ct-test-plan/SKILL.md`.
- No addon code changes, so there is no version bump.
