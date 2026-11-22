# Proposal

## Why

Testing KeepThat showed three problems. A tester could not tell which steps TestThat can check and which they confirm. After a Fail the card stayed on the same step, so the run looked stuck. There was no way to go back to an earlier step. A copy-box error was also reported.

## What Changes

- Each step shows who checks it: a green TESTTHAT CHECKS THIS STEP banner, or a gold YOU CONFIRM THIS STEP banner.
- Required checks are listed with a name and tick live (a check mark when seen) while the tester acts. Plans can give each check a player-readable `label`.
- Fail moves on, like the other results. Only missing evidence keeps a step open. The log records why evidence was missing.
- < and > buttons (and `/wtt back`, `/wtt next`) move through the steps. A finished step shows what was recorded and offers Redo.
- The copy boxes no longer pass the game's extra arguments to HighlightText; card button errors are logged instead of leaving the step looking stuck.

## Capabilities

### Modified Capabilities
- `test-runner-ux`: banner, live checks, navigation, redo
- `run-evidence`: Fail moves on; reason for missing evidence logged
- `test-plan-format`: assertion label

## Impact

`Model/Run.lua`, `Model/Evidence.lua`, `Model/App.lua`, `Core/Slash.lua`, `UI/Card.lua`, schema, `tools/wtt.py`, sample plans, tests, docs.
