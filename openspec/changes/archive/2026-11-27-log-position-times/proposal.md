## Why

Issue #158: an addon log that keeps its newest 300 lines is full late in a long plan. CheckThat finds where a step opened by searching for the 12 lines it saved then. When those lines repeat (the same merchant block on every visit), the place is ambiguous, so an absence or an upper count comes back unverified even when the addon is right. A replay of a 650-step plan failed this way near the end.

## What Changes

- `Evidence.ReadLog` also returns the entries' times for a log of `{ t, msg }` entries when every entry has a number `t`.
- A saved log position keeps `times`, the times of its tail lines. A run-scoped copy keeps them too.
- `Evidence.NewLines` matches a tail line only at the same time. When the tail's times are not all equal, the one place found is exact, also in a full ring with repeated blocks. Two places (the clock ran back) stay inexact. A tail written within one tick, a position saved without times, and `strings` logs keep the old rules.
- `Run.FORMAT_REV` 7: `times` in a saved position (saved variables only; the results string never carries positions).
- Docs: `features.md`, `results-format.md`.

## Capabilities

### Modified Capabilities
- `run-evidence`: a timed log finds where the step opened.

## Impact

`CheckThat/Model/Evidence.lua`, `CheckThat/Model/Run.lua` (revision), `tests/test_evidence.lua`, docs. Older positions read as before. The version bump is held per the release hold.
