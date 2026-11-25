# Proposal

## Why

A plan only observes the real client. It cannot force an API to return chosen values, call an addon function and check the result, expect a throw, fire an event with fake arguments, or count calls. Unit-test tools do. Issue #94 asks whether CheckThat can provide this itself, with no new dependency, and which parts are worth building.

## What Changes

- A standalone offline runner (`tools/entry_runner.lua`, run with luajit) loads an addon's TOC files under the fake client, with API mocks set before load. It calls entry points the addon registered, checks returns, throws and mock call counts, and fires fake events.
- A fixture addon (`tests/fixtures/mockaddon/`) and `tests/test_entries.lua` prove each claim, including the local-capture limit of in-game mocking.
- `docs/contracts.md` records what was measured (call-time lookups versus file-scope captures in the four addons, what the harness needed) and what stays unmeasured (taint).
- The spike has no plan-format change. The runner reads its own spec file, never a plan field.

## Capabilities

### New Capabilities
- `offline-entry-runner`: the offline runner and its spec file.

## Impact

- Code: `tools/entry_runner.lua`, `tests/fixtures/mockaddon/`, `tests/test_entries.lua`. Docs: `docs/contracts.md`, `docs/harvesting.md` is untouched.
- No file under `CheckThat/` changes: no version bump, changelog entry or tag.
- Follow-up issues carry the deferred parts (see design Non-Goals).
