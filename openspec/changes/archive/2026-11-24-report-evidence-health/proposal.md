# Proposal

## Why

A reviewer cannot tell from `ct.py` whether the collected evidence is healthy, a rerun that passed hides the earlier failure, the kept error stack needs the saved variables, and a CI job gets only Markdown. A run with many failed attempts can also outgrow the 2 MB export limit. Covers issues #78, #79 and #71.

## What Changes

- `ct.py status`: one row per run (done, fail, unverified, open, age, size estimate), unreadable revisions, logged conflicts, size near the limit. Exit 1 on a problem.
- `ct.py report`: a `result:` line, earlier failed attempts of a step that later passed, error stacks under the failed attempt, `--format json|junit`, `--strict`, `--stacks`, `--out`.
- `collect` keeps the saved error lines and stacks, logs conflicts and decode failures in `problems.log`, and no longer calls an export-stripped open attempt a conflict.
- Addon: a run keeps at most about 60 000 bytes of attempt excerpts (oldest dropped first). A step that stays open keeps one error stack.

## Capabilities

### Modified Capabilities
- `run-evidence`: the report, the excerpt budget, the stack for each attempt, evidence status and machine-readable reports.

## Impact

- Code: `tools/ct.py`, `tools/test_ct.py`, `CheckThat/Model/Run.lua`, `CheckThat/Model/App.lua`, tests. Docs: README, `docs/harvesting.md`, `docs/features.md`, `docs/skills.md`, `skills/ct-verify/SKILL.md`.
- Addon code changes: version 0.13.1.
