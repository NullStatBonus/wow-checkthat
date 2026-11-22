# Proposal

## Why

The first full live run found three problems. A tester needs a result between Pass and Fail for "mostly works". The Run button stuck out past the card. The "Reloaded" notice after a reload was not noticed. The character was saved without its realm.

## What Changes

- New verdict **Partial** (`/wtt partial [note]`): gated by evidence like Pass, moves on like Pass, counted and listed in the report with its note.
- The secure button is labelled **Run**, is 56 wide, and sits inside the card beside the first command (command boxes 190 wide).
- After a reload the card shows a green "Reloaded" line under the title, and chat says the run continues.
- The character key uses the full name with realm.

## Capabilities

### Modified Capabilities
- `run-evidence`: Partial verdict
- `test-runner-ux`: controls row, Run button fit, reload notice

## Impact

`Model/Run.lua`, `Model/App.lua`, `Core/Slash.lua`, `UI/Card.lua`, README, DESIGN.md, docs, tests.
