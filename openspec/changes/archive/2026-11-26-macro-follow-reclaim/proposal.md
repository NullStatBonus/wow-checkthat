## Why

A 0.20 macro plan failed in game on build 1.60.1.71139: every press of the macro key ran an old `/ct status` body, and CheckThat never rewrote the macro. With no step open, CheckThat writes `/ct status` without the marker line. Once the game body and the saved body differ (for example a trailing new line from the game) or the game refuses the edit, CheckThat treats the macro as the player's and never takes it back. A failed rewrite wrote nothing to the log, so the run gave no reason.

## What Changes

- Compare macro bodies without trailing spaces and new lines.
- A new run, or turning the setting on, also takes back a macro that holds only `/ct status`.
- Log `macro not set <step id>: <reason>` once for each new reason. When the game does not take an edit, say so in chat once.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-runner-ux`: the macro follow requirement takes back the empty body and compares bodies loosely; the rewrite log names a failure.

## Impact

`CheckThat/UI/Card.lua` (`writeMacro`, `Card.FollowMacro`), `tests/test_combat.lua`, `docs/features.md`, `docs/test-plan.md`, `CHANGELOG.md`. No saved-variable or format change.
