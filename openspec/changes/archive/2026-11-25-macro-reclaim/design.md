# Design

## Context

`writeMacro` treats a macro whose body differs from the saved body as the player's. The saved body then never matches, so every later sync returns early.

## Goals / Non-Goals

**Goals:** a player's edit lasts one run, and a stale macro recovers.

**Non-Goals:** keeping an edit across runs, or taking back a macro whose marker line was removed.

## Decisions

1. **Reclaim only when the first line is the marker.** The marker proves CheckThat made the macro. A macro without it is the player's.
2. **Reclaim at a run boundary.** The saved state keeps the run id of the last sync. A different current run, or the setting turning on, allows one take-back. Inside a run an edit is respected.
3. **Compare with the game's body.** The skip for "already right" compares the game's body, not the saved one, so a reclaimed macro that happens to match the saved body is still rewritten.

## Risks / Trade-offs

- [An edit made for one run is lost at the next] → accepted; `/ct macro` makes a separate macro to keep.
