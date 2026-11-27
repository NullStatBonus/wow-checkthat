## Why

Issue #250: every run records `character = "Name-Realm"`, so an exported results string names the tester's character and realm. The export window and the README said only that a plan's variables can reach the string.

## What Changes

- `Export.Show(title, text, note)` takes an optional sentence shown before the copy hint, in the AceGUI status line and in the plain window's hint.
- The results window passes "The results include your character and realm name."
- Docs: README, `features.md`, `results-format.md` (Privacy), `test-plan.md` (4.4).

An export without the character is not part of this change.

## Capabilities

### Modified Capabilities
- `run-evidence`: the export window says the results carry the character and realm.

## Impact

`CheckThat/Debug/Export.lua`, `CheckThat/UI/Card.lua`, tests, docs. No format change. The version bump is held per the release hold.
