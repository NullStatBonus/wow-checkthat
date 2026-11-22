# Proposal

## Why

The finished-run screen offered Export results and Reload. Reload was unexplained and not the next thing a tester wants; they want to get back to the main window to start another plan.

## What Changes

- The results screen replaces Reload with a Main window button that opens the settings window on Home (start a run, import a plan).
- The results text says the game saves evidence when you reload or log out.

## Capabilities

### Modified Capabilities
- `test-runner-ux`: results screen buttons

## Impact

`UI/Card.lua`, self-test handoff, DESIGN.md, tests.
