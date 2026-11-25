# Proposal

## Why

A run names the client, build and character, and the CheckThat version that wrote it, but not the version of the addon under test. `ct.py diff` and `ct.py trend` cannot say which addon version a result belongs to. This is part B of issue 92.

## What Changes

- A new run saves `targetVersion`: the TOC `Version` of the plan's addon, from a guarded `Adapter.AddonVersion(name)`. It is omitted when unknown, and never the text "unknown".
- `Run.FORMAT_REV` rises from 2 to 3. The run schema and `docs/results-format.md` list the key.
- `ct.py diff` shows it in the header. `ct.py trend --by target` names the columns by it. `--by version` keeps its meaning (the CheckThat version).

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-evidence`: the run records the tested addon's version.
- `run-verification`: diff and trend show it.

## Impact

- `CheckThat/Core/Adapter.lua`, `CheckThat/Model/Run.lua`, `CheckThat/Model/App.lua`, `schema/run-results.schema.json`, `tools/ct.py`, tests, README, `docs/`.
- Addon code changed: version 0.19.0 (new capability, before 1.0). Closes #92.
