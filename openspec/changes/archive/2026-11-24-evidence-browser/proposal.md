# Proposal

## Why

A reviewer reads a long report to find the failing steps. A terminal viewer shows runs, steps and one step's attempts, and follows the evidence folder. Covers issue #83.

## What Changes

- `tools/ct_tui.py` and `ct.py browse`: a read-only viewer with three screens (runs, steps, step), an export dialog and a help screen.
- `requirements-tui.txt` (Textual). It is optional and not part of the default install.
- The bundle for both installers includes the viewer and its requirements file.

## Capabilities

### Modified Capabilities
- `run-evidence`: the viewer.

## Impact

- Code: `tools/ct_tui.py`, `tools/ct.py`, `tools/test_ct_tui.py`, `tools/test_ct.py`, `Makefile`. Docs: README, `docs/harvesting.md`, `docs/skills.md`.
- No file under `CheckThat/` changes: no version bump, changelog entry or tag.
