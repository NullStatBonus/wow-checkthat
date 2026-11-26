# Design

## Context

Level 3 (2026-11-25-offline-lifecycle) loads an addon in the game's order. The fake client still accepts any event name, and its clock stands still.

## Goals / Non-Goals

**Goals:** refuse what the client refuses (an unknown event), check an event step's values against the client, and run timers in time order.

**Non-Goals:**
- `OnUpdate` scripts and frame-rate time: `wait` runs only timers.
- `date()`, `debugprofilestop` and other clocks.
- Types of event values: only their number is checked.
- Event lists for clients other than Era and Forever.

## Decisions

### D1. The event list comes from Blizzard's published source, not from a tester

The census does not list events. The client offers no way to list them either, only `C_EventUtils.IsEventValid(name)`. Blizzard's generated API documentation (`Blizzard_APIDocumentationGenerated`) gives each event's name and payload. For a payload value, `Nilable = false` means the game always sends it. About 100 events per client appear only in Blizzard's own `RegisterEvent` calls; they are listed with `documented: false`, and their values are not checked. The lists hold no tester data, so they are committed. Each records the source commit and build.

### D2. Picking the list

The client is the one the TOC's interface names: below 16000 Era, from 16000 Forever, as for census manifests. A TOC without an interface line gets 11507, so Era. A missing list fails the load step.

### D3. Error text

`RegisterEvent` raises `Frame:RegisterEvent(): Attempt to register unknown event "NAME"` at the caller's level. It is not measured in game; #163 can measure it with the lifecycle events.

### D4. The clock

- `H.clock(st, {start, epoch})` in the harness. `GetTime` starts at 1, as at the earlier levels, and `time()` is `epoch + floor(GetTime() - 1)`.
- `After(seconds, fn)` calls `fn()`. `NewTimer` and `NewTicker` return a handle with `Cancel` and `IsCancelled`, and call `fn(handle)`, as the API documentation's `TickerCallback` says.
- `st.advance(seconds)` runs every due callback in order of due time, then creation order, and sets the clock to each one's due time while it runs. A callback that throws does not stop the others; the wait step reports the first error.
- A ticker of 0 seconds moves on by 0.0001 seconds. A wait stops after 100,000 callbacks and fails, so timers that keep making 0-second timers cannot hang `ct.py offline`.
- `time(table)` converts a date with Lua's `os.time`, read before the runner hides `os`.
- `RegisterUnitEvent(event, unit1, unit2)` registers the event for those units only. A unit event reaches the frame only when its first value names one of them.
- Not measured: whether a `NewTimer` handle reads `IsCancelled()` true after it fired. Here it does.

### D5. Levels 1 to 3 do not change

Without level 4 the harness keeps `GetTime() == 1` and the queue in `st.timers`, and any event name registers and fires. A `wait` step below level 4 fails the load step, and the schema rejects it.

### D6. Census manifests are never bundled

`BUNDLE_DIR` named `tests/manifests`, so every local census file went into the installed skill and the plugin build. Now only the folder's README is copied.

## Risks / Trade-offs

- A list is a snapshot of one build. The Forever source is 1.60.1.71091; the census build was 71139. An event added since then fails offline until the list is rebuilt with `tools/events_manifest.lua`.
