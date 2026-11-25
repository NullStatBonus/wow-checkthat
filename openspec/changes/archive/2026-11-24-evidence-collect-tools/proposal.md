# Proposal

## Why

`ct.py collect` shells out to luajit to read saved variables, so a Windows machine without it cannot harvest (#91). It also looks for four hard-coded addons, so a plan for any other addon never has its saved variables collected (#90). Screenshot matching has a fixed 2 second slack that a network mount may exceed (#95).

## What Changes

- A pure-Python saved-variables reader gives the same JSON as `tools/sv2json.lua`. `sv_json` uses it. luajit stays as a cross-check in tests.
- `collect --plan <file>` collects the files that hold the plan's `logs.*.global` names, the plan's addon file and CheckThat's own file. With no plan the old four-addon list stays. `collect` prints each source's path, modified time and age, and warns about a global no file defines. The PowerShell copy script takes file names from a `-Names` parameter and prints the same facts.
- `collect --shot-slack SECONDS` sets the screenshot window slack (default 2).

## Capabilities

### Modified Capabilities
- `run-evidence`: the external collection scripts.

## Impact

- Code: `tools/ct.py`, `tools/Copy-CheckThatEvidence.ps1`, `tools/test_ct.py`, a fixture under `tests/fixtures/sv-edge/`. Docs: `README.md`, `docs/harvesting.md`, `docs/skills.md`.
- No file under `CheckThat/` changes: no version bump, changelog entry or tag.
