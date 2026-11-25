# Proposal

## Why

Release 0.16.0 left four known gaps: a collector that drops screenshots without saying so (#88), a report that cannot tell a reopened step from an untouched one after Undo (#85), a Categories window whose row menu runs only its first item on clients with no context menu (#84), and no way to see a category's steps in place (#86). They share the Categories window, the run record and `ct.py collect`.

## What Changes

- `ct.py collect` counts screenshots taken near a run but inside no attempt window, and says so. `--verbose` names the nearest attempt and the gap. `--all-shots` copies them to `runs/<id>/unassigned-shots/`.
- A step record gets a `reopened` flag when Undo or Rerun reopens a step that had a result. A finished attempt clears it. Remove from run clears it. The run format goes to revision 2. The report shows "awaiting retry" for a pending step that is flagged or holds a finished attempt, in the table and in the json and junit reports.
- Where the game has no context menu, a click on a Categories row shows a small list of buttons, one per item, instead of running the first item. This replaces the "first item runs" rule.
- Each Categories row gets an expand button. An expanded row lists its steps with the result in words and a mark. A click on a step row shows that step. Paging counts the extra rows.

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-evidence`: screenshot collection reports what it left out; a reopened step carries an explicit marker in the saved run and the reports.
- `test-categories`: the Categories window expands a category into its steps.
- `test-runner-ux`: a Categories row reaches every item without a context menu (replaces "the first item runs").

## Impact

- `tools/ct.py` (`collect_shots`, `cmd_collect`, `run_shots`, `step_table`, `classify`, `run_model`), `tools/test_ct.py` (also its `formatRev` 1 checks and the results-format page check), `skills/ct-verify/SKILL.md` if it describes the old inference.
- `CheckThat/Model/Run.lua` (`Undo`, `Rerun`, `Deselect`, attempt finish, `FORMAT_REV`), `CheckThat/Model/App.lua`, `CheckThat/UI/Tracker.lua`, `CheckThat/Core/Adapter.lua` (`ContextMenu` falls through when `MenuUtil` errors).
- `schema/run-results.schema.json`, `docs/results-format.md`, `docs/features.md`, `docs/harvesting.md`, `docs/contracts.md`, `docs/listing.md`, `docs/test-plan.md`, `README.md`, `tests/test_run.lua`, `tests/test_app.lua`, `tests/test_tracker.lua`.
- Addon code changes: version 0.17.0 (new visible feature), TOC files and `CHANGELOG.md` at archive. Closes #84, #85, #86, #88.
