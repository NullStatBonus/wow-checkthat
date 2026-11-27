## Why

Issue #65: blocked-action events reached CheckThat only through BugGrabber, which records them as errors. So the same blocked action failed a "no Lua error" step with BugGrabber installed and passed it without. A plan could also not check that "nothing was blocked". Verdicts must not depend on an optional addon, and `global.errors` is a documented contract, so this has to be settled before 1.0.

## What Changes

- New `Model/Blocked.lua`. While a run is open, it records `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, `MACRO_ACTION_BLOCKED` and `MACRO_ACTION_FORBIDDEN` in `global.blocked`.
  - Each line reads `<time>.<counter> [<addon>] <EVENT> <function>`.
  - It keeps 50 lines and records at most 10 a second.
  - The addon and function are cleaned of brackets and control characters.
- `Core/Addon.lua` listens for the four events through `ns.Listen`, which skips an event the client lacks.
- `Errors.Sample` leaves BugGrabber's copies of these events out of `global.errors`.
- Debug log lines, a `Blocked actions: <n> recorded` line in the debug report, and docs (README, `features.md`, `authoring-plans.md` source example, `contracts.md`).

## Capabilities

### Modified Capabilities
- `run-evidence`: blocked actions are their own quiet source, and the error list no longer depends on BugGrabber.

## Impact

`CheckThat/Model/Blocked.lua` (in both TOCs), `Errors.lua`, `App.lua`, `Core/Addon.lua`, `Debug/Log.lua`, tests, docs. `global.blocked` is additive. `global.errors` stops holding BugGrabber's blocked-action lines, a fix that makes the list the same on every install. The version bump is held per the release hold.
