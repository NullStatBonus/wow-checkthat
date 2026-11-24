# Proposal

## Why

The run record had a version number (`ct`) that nothing checked. It grew three times (categories, excerpts, check detail) with no marker, so a tool could not tell an old run from a run where nothing matched, and a CheckThat of an older major version could damage a run it could not read. The format must be able to keep changing.

## What Changes

- `ct` stays the major version. `formatRev` is a new revision that rises with every additive change. `writerVersion` names the CheckThat that last changed the run. A finished attempt carries `formatRev`.
- A run with a higher `ct` moves to `global.future` when the addon loads and is never touched; a chat line says so. It moves back when this version can read it.
- `ct.py` refuses a higher `ct` before it reads the shape, names it in `status`, `collect` and `report`, and `report --strict` fails when a newer revision was skipped.
- `docs/results-format.md` is the contract, with the reader and writer rules and the revision table; a test keeps it in step with the code. The schema gets the stamps.

## Capabilities

### Modified Capabilities
- `run-evidence`: format stamps, newer runs kept aside, tools refuse a newer major.

## Impact

- Code: `CheckThat/Model/Run.lua`, `CheckThat/Model/App.lua`, `CheckThat/Core/Addon.lua`, `CheckThat/Debug/Log.lua`, `tools/ct.py`, `tools/ct_tui.py`, `schema/run-results.schema.json`, tests. Docs: `docs/results-format.md`, README, `docs/features.md`, `docs/harvesting.md`, `skills/ct-verify/SKILL.md`, `docs/test-plan.md`, `CHANGELOG.md`.
- Addon code changes: version 0.15.0 (new capability, before 1.0).
