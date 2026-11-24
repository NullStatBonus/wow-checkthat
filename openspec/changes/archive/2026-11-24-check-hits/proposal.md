# Proposal

## Why

A failed or unverified check saved only a result and a short reason. A reviewer, the viewer or any other tool could not say which log line caused it: the excerpt holds the first 20 new lines, not the matching ones, the check's rule lives only in the plan, and a forbidden line failed with no reason at all.

## What Changes

- Every check outcome that is not a pass saves what it looked at: `kind`, `scope`, `source`, `label`, `rule`, `window`, `matched`, up to 3 `hits` (`n`, `line`, and `item` or `value`), `stoppedAt`, `observed`, `trimmed`. All keys are optional; the results string stays version 1.
- The detail comes from the same read that judged the check. Hit text counts toward the run's byte budget.
- Missing reasons are filled: a forbidden line, and facts that do not match.
- `schema/run-results.schema.json` describes the run record. `ct.py` validates hits, shows the check and its lines in the report, marks them in the excerpt, and adds them to `--format json|junit` (line text only with `--lines`). The viewer shows a panel for each failed check and marks the lines.

## Capabilities

### Modified Capabilities
- `run-evidence`: check detail, the byte budget, the report and the schema.

## Impact

- Code: `CheckThat/Model/Evidence.lua`, `CheckThat/Model/Run.lua`, `tools/ct.py`, `tools/ct_tui.py`, `schema/run-results.schema.json`, tests. Docs: `docs/features.md`, `docs/harvesting.md`, `docs/test-plan.md`, `skills/ct-verify/SKILL.md`, `CHANGELOG.md`.
- Addon code changes: version 0.14.0 (new capability, before 1.0).
