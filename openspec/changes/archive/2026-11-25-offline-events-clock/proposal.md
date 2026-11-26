# Proposal

## Why

The fake client accepts any event name: `RegisterEvent` records whatever it is given, and an offline `event` step fires any name with any arguments. On Era and Forever the client refuses an unknown event (`C_EventUtils.IsEventValid` exists on both), so an addon with a typo in an event name passes offline and fails in the game. `GetTime` is the constant 1 and `C_Timer.After` only queues its callback, so no offline check can show that a delayed action happens, or happens at the right time (#150).

## What Changes

- **Offline level 4.** Everything in level 3, plus:
  - **The client's event list.** `tools/events/era.json` and `tools/events/forever.json` list every event the client has, with the number of values each carries. They come from Blizzard's published UI source: the generated API documentation, and the events Blizzard's own code registers. The runner picks a list by the TOC's interface (below 16000 Era, from 16000 Forever).
    - `RegisterEvent` and `RegisterUnitEvent` raise the client's error for an event the list lacks.
    - An `event` step that names an unknown event, or gives more values than the event carries or fewer than it always carries, fails the load step before any addon file runs.
  - **A virtual clock.** `GetTime`, `time()`, `C_Timer.After`, `C_Timer.NewTimer` and `C_Timer.NewTicker` follow it.
    - A new `wait: <seconds>` step moves it on and runs each timer that comes due. Timers run in order of due time, then in the order they were made. A timer made during a wait runs in that wait when it comes due.
    - The clock goes on across a reload, but the timers do not survive it. Each group starts again at 1.
- **`tools/events_manifest.lua`** builds a list from a checkout of Blizzard's UI source, one event per line, so a new build's list diffs cleanly.
- Census manifests are never bundled: `make install-skill` and `make build-plugin` copied the whole `tests/manifests` folder, local census files included.

## Capabilities

### Modified Capabilities

- `offline-entry-runner`: level 4.
- `test-plan-format`: `level` accepts 4, and the new `wait` step needs it.

## Impact

- Tools: `tools/entry_runner.lua`, `tests/harness.lua` (`H.clock`), `tools/events_manifest.lua` (new), `tools/events/*.json` (new), `tools/ct.py`, `schema/test-plan.schema.json`, `Makefile`.
- Tests: `tests/test_entries.lua`, `tests/fixtures/MockAddon/Clock.*`, `tools/test_ct.py`.
- Docs: `docs/authoring-plans.md`, `docs/contracts.md`, `skills/ct-test-plan/SKILL.md`.
- No addon code changes, so there is no version bump.
