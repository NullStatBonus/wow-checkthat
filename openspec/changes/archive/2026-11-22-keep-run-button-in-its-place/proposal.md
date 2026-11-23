# Proposal

## Why

In the in-game self-test the Run button of step 4 (a step with a command) stayed on screen after the player left that step, first over the export window and, after the window was raised, still floating on it at a different height. The card hides the button on every redraw, but the button is also driven by the game's own `[combat] hide; show` state driver, and it is a separate top-level frame at the same strata as the export window. Nothing makes sure it shows only with a step that has commands.

## What Changes

- The copyable text window (report, results string, plan import) draws above the card and the Run button (`FULLSCREEN_DIALOG`).
- The Run button is shown only while the card shows an open step that has commands. If anything else shows it out of combat (the combat driver, a late timer), the card hides it again at once and writes one debug log line, so the next test can show what showed it.
- One manual check covers both.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `test-runner-ux`: the text window draws above the Run button; the Run button shows only with a step that has commands.

## Impact

- Code: `CheckThat/Debug/Export.lua` (frame strata), `CheckThat/UI/Card.lua` (a wanted flag and an `OnShow` guard on the secure button).
- Docs: `docs/test-plan.md` (two manual checks), `CHANGELOG.md` at archive.
- Tests: `tests/test_layers.lua` (new), `tests/test_smoke.lua`.
- Addon code changes, so the version rises at archive: a fix is a patch bump (0.5.1).
- No design.md: two local guards with no alternatives worth recording. The guard is defensive: the exact cause in the game is not proven, so the log line is part of the change.
