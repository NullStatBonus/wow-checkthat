# Proposal

## Why

Issue #99. A developer may want entries to run at login and report pass or fail without opening a run. Entries exist since #97.

## What Changes

- Setting `loginCheck`, off by default, on the settings page with help text that says what it does.
- After login (3 seconds), outside combat, CheckThat calls each entry named by an imported plan's auto step and compares the fact line with the step's required `equals` or `contains` log checks.
- It prints one chat line. It records no fact and opens no run. The result lives in chat and the debug log.
- The setting shows in the debug report through the profile list.
- Ships in 0.18.0 with #97.

## Capabilities

### New Capabilities
- `login-self-check`: the opt-in check.

### Modified Capabilities

## Impact

- `Core/Defaults.lua`, `Core/Addon.lua`, `Model/App.lua` (`App.SelfCheck`), `Options/Options.lua`, README, `docs/features.md`, CHANGELOG, `tests/test_selfcheck.lua`.
