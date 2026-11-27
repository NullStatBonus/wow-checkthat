## Why

Issue #252 (part 1 of 2): settle the plan and run format names that 1.0 freezes. Agreed decisions 1 to 3 on the issue.

## What Changes

- **Client names.** Plans accept `era` and `forever` as short names for `classic-era` and `forever-camelot` (`Plan.CLIENT_ALIAS`, `ct.py CLIENT_ALIAS`, the plan schema). `compile` writes the long names, so a compiled plan still imports into an older CheckThat. Runs keep the long names.
- **Unknown client.** `App.Client()` returns nil unless the interface number is 11000 to 11999 (`classic-era`) or 16000 to 16999 (`forever-camelot`). It no longer guesses Era. A nil client runs only the steps without `clients`.
- **Open lists in the run record.** `by`, `evidence` and `at` on an attempt and `kind`, `scope` and `since` on an outcome become open: the schema types them as strings with today's values as `examples`, and `results-format.md` tells readers to accept unknown values. `verdict` and `result` stay closed.
- **`Run.New`** writes `ct = Run.MAJOR`, not a literal.

## Capabilities

### Modified Capabilities
- `test-plan-format`: short client names.
- `run-lifecycle`: an unknown client is nil; open lists in the run record.

## Impact

`CheckThat/Model/Plan.lua`, `App.lua`, `Run.lua`, `schema/*.json`, `tools/ct.py`, tests, `authoring-plans.md`, `results-format.md`. Backward compatible: existing plans and runs read as before. The version bump is held per the release hold.
