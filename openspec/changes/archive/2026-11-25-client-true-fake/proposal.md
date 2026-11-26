# Proposal

## Why

The fake client decides by hand which APIs exist, and any frame accepts any method (#145). An addon that calls a function only one client has, or misspells a frame method, passes offline. The census from #146 now records what each client defines.

## What Changes

- **Client surfaces.** `tools/clients/era.json` and `tools/clients/forever.json` are reviewed slices of the in-game census, holding game-defined names only:
  - global functions;
  - the function members of `C_` namespaces;
  - the methods of 16 widget types.

  `tools/client_slice.py` makes them from a local manifest. The tester's addon list, addon globals and data values are left out, and the raw manifests stay local.
- **Strict fake client.** `H.stubClient({client = "era" | "forever"})`:
  - only the client's game functions exist;
  - a function it does not model is a stub that returns nothing;
  - Lua aliases are the Lua functions;
  - `GetBuildInfo` gives the real build;
  - a frame of a listed type without a template has only its type's methods.

  The default fake client is unchanged.
- **Offline level 5** uses the strict fake client of the client the TOC names, and refuses a mock of a function that client lacks.
- **CheckThat runs on both surfaces** in `make test`, with its own TOC for each.

## Capabilities

### Modified Capabilities

- `offline-entry-runner`: level 5, and CheckThat on both surfaces.
- `test-plan-format`: `level` accepts 5.

## Impact

- Tools: `tests/harness.lua`, `tools/entry_runner.lua`, `tools/client_slice.py` (new), `tools/clients/*.json` (new), `tools/ct.py`, `schema/test-plan.schema.json`, `Makefile`.
- Tests: `tests/test_clients.lua` (new), `tests/test_entries.lua`, `tools/test_ct.py`.
- Docs: `docs/authoring-plans.md`, `docs/contracts.md`, `docs/harvesting.md`, `skills/ct-test-plan/SKILL.md`.
- No addon code changes, so there is no version bump.
