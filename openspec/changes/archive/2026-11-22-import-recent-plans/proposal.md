# Proposal

## Why

Testers re-import the same plans. Pasting a long string each time is slow, and the string must be found again.

## What Changes

- The import screen keeps its text box and adds a "Recent plans" dropdown listing plans used before (newest first, up to 8, no duplicates).
- Picking one makes it the current plan at once, opens the window with Start run, and needs no paste.
- Importing a string or picking a plan moves it to the front of the list.

## Capabilities

### Modified Capabilities
- `test-runner-ux`: import screen

## Impact

`Model/App.lua`, `Debug/Export.lua`, `UI/Card.lua`, tests, DESIGN.md, docs/test-plan.md, CHANGELOG.md.
