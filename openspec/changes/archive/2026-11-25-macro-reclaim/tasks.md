# Tasks

## 1. Take the macro back

- [x] 1.1 In `Card.lua`, pass a reclaim flag to `writeMacro`: a changed macro whose first line starts with `/ct macrorun ` is rewritten when the flag is set. `FollowMacro` sets it when the setting just turned on or the current run differs from the saved run id, and saves the run id after a write. Compare with the game's body to skip. Tests in `tests/test_combat.lua`: an edit in a run stays, a new run takes it back, turning the setting on takes it back, a macro without the marker is never taken back. Break the flag, see the test fail, restore it.
- [x] 1.2 Update `docs/features.md` and the README line about edited macros. `make test` and `make check` pass.

## Workflow follow-up

- Archive the change. The version stays 0.20.0.
