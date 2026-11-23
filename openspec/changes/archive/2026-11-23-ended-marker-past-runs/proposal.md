# Proposal

## Why

A Past runs row reads `date plan (character): n pass, n fail, n open` for an ended run and for an unfinished run. A tester cannot pick the run that asks before it replaces the current run apart from a run that only opens for viewing. A test run of the 0.8 plan failed two steps for this reason. Covers issue #49.

## What Changes

- The row of an ended run ends with `, ended` after the counts.

## Capabilities

### New Capabilities

### Modified Capabilities
- `addon-settings`: Past runs rows show whether a run ended.

## Impact

- Code: `runText` in `CheckThat/Model/App.lua`. Tests: `tests/test_app.lua`. Docs: `README.md`, `docs/test-plan.md`, `CHANGELOG.md`. Version 0.8.2.
