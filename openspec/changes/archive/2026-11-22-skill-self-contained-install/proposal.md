# Proposal

## Why

`make install-skill` copies only the skill text and records the checkout path. The skill then runs `tools/wtt.py` from that checkout, with whatever Python the user has. It fails when the checkout moves or is gone, or when PyYAML or jsonschema is missing. An author working in another addon repo should need no TestThat checkout.

## What Changes

- `make install-skill` also installs a bundle beside the skill: `tools/wtt.py`, the schema, `docs/test-plan.md`, the format spec, `Plan.lua` (for the allow list), `requirements.txt` and a version stamp. The bundle mirrors the checkout layout.
- The install builds a private virtualenv in the skill folder and installs PyYAML and jsonschema into it. No system Python change.
- The skill finds the bundle beside itself first, then falls back to a checkout. It runs `wtt.py` with the private Python.
- The skill stops writing a checkout path. It asks where to save the plan, with no TestThat default.
- Install fails with a clear message when `python3`, `venv` or the package download is unavailable, and keeps the earlier copy.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-authoring`: tool discovery uses the installed bundle; install bundles tools and dependencies.

## Impact

- `Makefile`, `skills/wtt-test-plan/SKILL.md`, `reference.md`, `tools/test_wtt.py`, README install text.
- Install now needs Python 3 with `venv` and network access once. No addon, schema or saved-data change.
