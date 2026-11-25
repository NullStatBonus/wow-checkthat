# Proposal

## Why

Issue #97. The offline runner (#94, #96) uses a stub `CheckThat.Entry`. The real API does not exist, so an addon cannot expose a function for a plan step to call in the game. The taint probe (#98) decides in-game mocks only; the #94 decision says entry points are built.

## What Changes

- **`CheckThat.Entry(addon, name, fn)`** registers an entry point at addon load. `CheckThat.API_VERSION` becomes 2.
- **Step field `call`** on an auto step: `{addon, entry, args}` with literal arguments. CheckThat calls the entry when the step's attempt opens, outside combat, in `pcall`.
- **The outcome is a fact line** `[addon] entry.<name>=<result>`, so a plan checks it with the existing fact and log checks. A throw reads `threw: <text>`; an unknown name reads `not registered`; combat reads `refused: in combat`.
- Registration is allowed at any time (changed in review: a run survives a reload). A reload does not repeat the call.
- Version 0.18.0.

## Capabilities

### New Capabilities
- `entry-calls`: addon-registered entries and the auto-step call.

### Modified Capabilities
- `test-plan-format`: the step `call` field.

## Impact

- `CheckThat/Model/Entries.lua` (new, both TOCs), `Facts.lua`, `App.lua`, `Plan.lua`, `Core/Adapter.lua` (combat read), schema, `tools/ct.py`, tests, docs, CHANGELOG, TOC versions.
