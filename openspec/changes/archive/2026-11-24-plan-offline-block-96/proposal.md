# Proposal

## Why

Issue #96. The offline runner (#94) reads its own spec file, so mocks, entry calls and fake events cannot ship with a plan or run in the build. A plan author has no place to say "call this entry and expect this value".

## What Changes

- **Plan field `offline`**: an optional top-level block with `toc`, `mocks`, `mockAfterLoad` and `steps` (`call`, `event`, `mockCalls`, with `returns` or `throws`). It mirrors the runner's spec.
- **`ct.py validate`** checks the block against the schema.
- **`ct.py compile`** removes the block, so the game never receives it and the plan digest ignores it.
- **`ct.py offline <plan> [-o junit.xml]`** runs the block in `tools/entry_runner.lua`. It prints JUnit, exits 1 when a step fails and 2 on an error (no block, no luajit, a bad mock). `toc` resolves from the plan file's folder.
- **Mock allow list**: the runner holds a closed list of mockable APIs. A plan cannot extend it.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-format`: the optional offline block and its removal at compile.
- `offline-entry-runner`: runs a plan's block, with a closed mock allow list.

## Impact

- `tools/ct.py`, `tools/entry_runner.lua`, `schema/test-plan.schema.json`, `tools/test_ct.py`, `tests/test_entries.lua`, a fixture plan, `docs/authoring-plans.md`, `README.md`.
- No file under `CheckThat/` changes, so there is no version bump.
