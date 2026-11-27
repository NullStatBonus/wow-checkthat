# Proposal

## Why

A plan's last step checks that no Lua error happened (#161). Today an assertion reads either `attempt` (lines since the step opened, which misses errors from earlier steps) or `session` (the whole saved log, which keeps errors from earlier runs and other plans across `/reload`). A clean run then fails because of an old error, or a real error from step 3 goes unseen. The foundation plans from #219 end with this step, so they need the fix before the 0.21.0 release.

0.21.0 also added `CheckThat.OnRun` (#171), but `CHANGELOG.md` has no line for it.

## What Changes

- Log, log-sequence and fact assertions accept `scope: run`: every line written since the current run started, across `/reload`.
- When a run starts, CheckThat saves where each log source the plan names stands, as it does today when a step opens. A `run`-scoped check reads the lines after that position.
- `ct validate`, the schema, `ct replay`, `ct report` and `ct show` know the new scope. A run saved before the change has no start positions: a `run` check on it is unverified, never pass.
- `CHANGELOG.md` 0.21.0 gets its missing OnRun line, and this change adds its own line there.
- The plan skill and the docs stop pointing at #161 and recommend `scope: run` for the final no-error step.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-format`: the assertion scope enum gains `run`.
- `run-evidence`: a run saves log positions at start, and a `run`-scoped check reads from them.
- `test-plan-authoring`: the skill recommends `scope: run` for the final no-error step.

## Impact

- `CheckThat/Model/Evidence.lua` (window, Snapshot, Preview), `Run.lua` (New, FORMAT_REV), `App.lua` (Start), `Plan.lua` (scope check).
- `schema/test-plan.schema.json`, `tools/ct.py` (validate, report, show, replay), `tests/replay_plan.lua`.
- `skills/ct-test-plan/`, `docs/authoring-plans.md`, `docs/results-format.md`, `docs/test-plan.md`, `CHANGELOG.md`.
- The version stays 0.21.0, which is not tagged yet.
