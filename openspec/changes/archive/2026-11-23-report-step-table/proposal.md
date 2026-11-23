# Proposal

## Why

`ct.py report` hides everything about passing steps, so a reviewer cannot see how a pass was reached. Covers issue #10.

## What Changes

- `ct.py report` prints a table of every step: verdict, evidence state, attempt count and note. Detail lines stay for non-passing steps.

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-evidence`: the central report lists every step.

## Impact

- Code: `tools/ct.py` (`report_text`), `tools/test_ct.py`. Docs: `README.md`.
- No file under `CheckThat/` changes. No version bump, no changelog entry, no tag.
