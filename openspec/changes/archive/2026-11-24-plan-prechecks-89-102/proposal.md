# Proposal

## Why

A plan can fail for reasons that are not in the addon under test. Issue #102: a plan asserted the log line its own result press writes, the game ran a wrong build, and a tester lost two runs. Issue #89: nothing fails a build when a plan's `contains` or `pattern` drifts from the addon's real log text. Both are plan faults that tools can catch before a player runs the plan.

## What Changes

- **`ct.py replay <plan> --sv <fixture dir>`** judges each step's log and fact checks against a saved-variables fixture with the real `Model/Evidence.lua` under luajit. It prints JUnit and exits non-zero when a required check is contradicted.
- Checks that need a step window or a state the fixture lacks report "not judged offline". They never pass.
- The report prints the fixture's age and the plan digest it was recorded with.
- **`ct.py validate` lint** (#102): error when a step asserts `[ct] step <own id> `; warning when the first step of a plan has no version check.
- **Bundle check** (#102): the skill warns when `$CT/VERSION` is older than the checkout and names `make install-skill`.
- **Skill rules** (#102): ask auto or manual for each step, end manual `expect` text with the press it needs, default an auto `timeout` to 120, run `tests/replay_plan.lua` after `compile` and show the result in the review, and make a new-UI check say what the tester should see.

## Capabilities

### New Capabilities
- `plan-replay`: offline judgment of a plan's checks against a saved-variables fixture.

### Modified Capabilities
- `test-plan-format`: validation lint for self-judging assertions and a missing version check.
- `test-plan-authoring`: skill draft rules, the bundle staleness warning and the replay review step.

## Impact

- `tools/ct.py`, a new luajit driver under `tools/`, `tools/test_ct.py`, a new Lua test, `skills/ct-test-plan/`, `docs/authoring-plans.md`, `docs/harvesting.md`, `README.md`.
- No file under `CheckThat/` changes, so there is no version bump.
