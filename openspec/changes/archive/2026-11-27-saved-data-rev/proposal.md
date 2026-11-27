## Why

Issue #248: the saved-variables root carries no shape revision, and there is no migration code. AGENTS.md requires migrating "only from a known older shape". From 1.0 a change of saved data shape needs a known starting point, so the stamp must exist before 1.0.

## What Changes

- `CheckThatDB.global.dbRev` is the shape revision of the saved global table. `App.DB_REV` is 1.
- `App.Migrate` runs at the start of `App.Init`. A table without `dbRev` (0.21.0 or older) is revision 0, which has the same shape as 1, and gets `dbRev = 1` with no other change. `App.MIGRATIONS[n]` takes revision n - 1 to n. The list is empty for now, and each step runs once.
- A higher revision written by a newer CheckThat is left as it is, never lowered. An unreadable value is left too. The debug log records each case.
- The debug report prints `Saved data: rev <n>`, and says when the revision is newer.
- `dbRev` is written by code and not set in `Core/Defaults.lua`, because AceDB drops a saved value that equals its default.

## Capabilities

### Modified Capabilities
- `debug-tools`: the report names the saved-data revision.

## Impact

`CheckThat/Model/App.lua`, `CheckThat/Debug/Log.lua`, tests, `docs/features.md`, `docs/results-format.md`. Additive: an older CheckThat ignores `dbRev`. The version bump is held per the release hold.
