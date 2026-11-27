## Why

The in-game run of the any-addon plan (3.24) and the self-test on Forever showed two faults:

1. The import window never used the AceGUI frame: `aceImport` called `SetButtonText`, which the shipped MultiLineEditBox lacks, so it raised and the plain window opened every time (`import window: plain window, AceGUI failed: Export.lua:135: attempt to call a nil value`). The tests' stub widgets answer any method, so they missed it.
2. `/ctp` (CTProbe) had no Run button: `plan commands offered: none; not offered: /ctp /help`. Nothing records why.

## What Changes

- `aceImport` sets the Import label on the widget's `button` frame. A new test reads the shipped AceGUI widget sources and fails when the text windows call a method the widget lacks.
- `Adapter.SlashOwner` returns a second value saying how it decided (the `SLASH_` global and its owner, or why there is none). It reads globals with a normal lookup, lists `SlashCmdList` first and reads each key in its own `pcall`, so one unreadable key no longer hides the rest.
- At run start CheckThat logs `plan command <cmd>: <how>` for each plan command it checked with the game.
- Docs: `features.md`, `test-plan.md` 3.24, `contracts.md` (pending in-game).

## Capabilities

### Modified Capabilities
- `test-runner-ux`: the import window uses the AceGUI frame.
- `run-evidence`: the start logs how each plan command was checked.

## Impact

`CheckThat/Debug/Export.lua`, `CheckThat/Core/Adapter.lua`, `CheckThat/Model/App.lua`, tests, docs. The version bump is held per the release hold.
