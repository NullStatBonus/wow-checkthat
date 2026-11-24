# Proposal

## Why

The report is long, and a reviewer who fixes a failing step has to scan all of it again and rerun `status` by hand. Small non-interactive commands cover most of that and are the base for a later viewer.

## What Changes

- `ct.py show <run> [step]`: one run, or one step with every attempt, excerpt and stack.
- `ct.py report --failed-only`: only failed or unverified steps.
- `ct.py status --watch [--interval n]`: status again every n seconds.

## Capabilities

### Modified Capabilities
- `run-evidence`: the central report can be narrowed, one step can be shown, status can be watched.

## Impact

- Code: `tools/ct.py`, `tools/test_ct.py`. Docs: README, `docs/harvesting.md`, `skills/ct-verify/SKILL.md`.
- No file under `CheckThat/` changes: no version bump, changelog entry or tag.
