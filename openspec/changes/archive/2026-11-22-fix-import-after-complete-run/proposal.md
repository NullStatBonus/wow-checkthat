# Proposal

## Why

After a run finished, importing a new plan left the card on "Run complete". The new plan never showed its Start screen, so the testing flow did not restart.

## What Changes

- A newly imported or chosen plan takes focus: the card shows it with Start run, even after a finished run.
- If the earlier run is unfinished, the card also offers Resume run.

## Capabilities

### Modified Capabilities
- `test-runner-ux`: import takes focus

## Impact

`Model/App.lua`, `UI/Card.lua`, tests, CHANGELOG.md.
