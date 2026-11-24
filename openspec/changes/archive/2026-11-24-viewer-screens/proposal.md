# Proposal

## Why

The step screen is a colored dashboard; the runs and steps screens are plain tables. A reviewer wants the same scan-at-a-glance on all three, on a 40-column terminal as well as a wide one.

## What Changes

- Runs: a strip that counts runs by state, a result word and mark, steps done over steps that apply; plan, revision, counts and age from 76 columns.
- Steps: a header with the run result, category chips (wide) and the filter, result words and marks, reason and category from 76 columns, "No matching steps".
- Category chips follow the evidence, not the player's verdict.

## Capabilities

### Modified Capabilities
- `run-evidence`: the viewer's runs and steps screens.

## Impact

- Code: `tools/ct_tui.py`, `tools/test_ct_tui.py`. Docs: `docs/harvesting.md`.
- No file under `CheckThat/` changes: no version bump, changelog entry or tag.
