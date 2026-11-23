# Proposal

## Why

AGENTS.md and the `debug-tools` spec say every game call lives in `Core/Adapter.lua`. `UI/Card.lua` and `Debug/Export.lua` still call `CreateFrame`, `UIParent` and `GetEffectiveScale` directly (issue #4). The sibling addons (ClosestVendor, DontDoThat, KeepThat) all let their UI files build frames and keep only queries and actions in the adapter. A nil-returning wrapper adds nothing for frame construction: a missing frame breaks the next line anyway. The rule should say what the code and the siblings already do.

## What Changes

- Reword the AGENTS.md convention: game API reads and actions stay in `Core/Adapter.lua`; `UI/` and `Debug/` may create, anchor and style their own frames.
- Modify the `debug-tools` requirement to state the same carve-out.
- Add a layering test that fails when game globals appear in `Model/`, `Core/` (outside the adapter) or `Options/`.
- No addon behavior changes. No file under `CheckThat/` changes.

## Capabilities

### New Capabilities

### Modified Capabilities
- `debug-tools`: "Game calls go through the adapter" gains the UI frame-construction carve-out.

## Impact

- `AGENTS.md`, `openspec/specs/debug-tools/spec.md` (at archive), `tests/test_layers.lua`.
- No version bump, changelog entry or tag (no addon code changed).
- Closes issue #4.
