# Proposal

## Why

`ct.py report` and `show` judge one run. Nothing says which steps changed between two runs, or which steps are flaky across many. A tester compares runs by eye.

## What Changes

- New `ct.py diff <A> <B> [--format md|json] [--strict] [--include-open]`: one label for each step (`regressed`, `fixed`, `newly-unverified`, `still-failing`, `not-comparable`, `added`, `removed`) and a header that names client, build, character, plan digest and writer version.
- New `ct.py trend [--addon X] [--title T] [--by ...] [--last N] [--format md|json] [--include-open]`: one row for each step, one column for each run, flaky steps marked.
- Plan changes are handled with step fingerprints from the collected `planStore`. A missing plan prints a warning and never a guess.
- The `ct-verify` skill and the docs mention both commands.

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-verification`: compare finished runs.

## Impact

- `tools/ct.py`, `tools/test_ct.py`, `README.md`, `docs/harvesting.md`, `docs/skills.md`, `skills/ct-verify/SKILL.md`.
- No change under `CheckThat/`: no version bump, no changelog entry. Refs #92 (part A only).
