## Why

Issue #252 (part 2 of 2): settle the public names 1.0 freezes. Agreed decisions 4 to 8 on the issue.

## What Changes

- **Public API** (`docs/contracts.md`): "Since" filled (0.21.0 for `OnRun`, `ActiveRun`, `Commands` and `global.blocked`). The `end` reasons are a closed list. A reload or logout sends no `end`. `digest` is a 32-bit Adler-32 checksum, and a local collision adds `-2`, so it can differ by machine.
- **Bindings**: `CHECKTHAT_PASS`/`PARTIAL`/`FAIL`/`SKIP` and `CheckThat_Key` are recorded as permanent.
- **Developer commands**: `/ct macrorun`, `/ct selftest`, `/ct fact` and `/ct census` move to a README table marked not stable. They keep working.
- **Runs to keep**: the default stays 20. When starting a run deletes old runs, chat names each one: "Deleted the oldest run (<plan>) to keep 20."
- **Plan `version`**: documented as an author label that CheckThat does not read (schema description, `authoring-plans.md`).

## Capabilities

### Modified Capabilities
- `run-lifecycle`: pruning says so in chat.

## Impact

`CheckThat/Model/App.lua` (one chat line), README, `contracts.md`, `features.md`, `authoring-plans.md`, the plan schema, `tests/test_app.lua`. The version bump is held per the release hold.
