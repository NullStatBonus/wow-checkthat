# Design

## Context

`Evidence.ReadLog(src, env)` already returns the times of an `entries` log (`{ t, msg }`) as a second value, and `Evidence.NewLines` already uses them to place the boundary of a step's window (#158). Nothing passed those times on to a check, so a sequence could not use them. `CheckSequence` matched greedily, one pass over the window.

## Goals / Non-Goals

**Goals:**
- A gap a plan can name, judged from the times the log already keeps.
- Never a pass and never a fail on a time the addon cannot read: a gap it cannot measure is unverified.
- The same answer from `Plan.lua`, the schema and `tools/ct.py`, and an older CheckThat refuses the plan.

**Non-Goals:**
- Times for a source that keeps none, such as a `strings` log. The feature reads the `entries` format only.
- Reading a time out of a `<sec>.<n>` line prefix. Nothing in a plan can name that shape yet.
- A gap on the first item. It has no earlier line, and validation refuses it.
- A new result key: a timed check uses `matched`, `window` and `stoppedAt` as an untimed one does.

## Decisions

- **Chain from the last item back.** For each item, keep the positions that can complete the rest of the sequence. An item's position is feasible when the first feasible position of the next item after it is within the gap; a later position of that item gives less time, so the first one decides. Walking back means an early line of an item that leaves too little time is dropped rather than failing the whole check, which the greedy pass could not do.
- **Only when an item gives `within`.** A plan without one keeps the untimed pass, its cost and its result, and never reads a time.
- **The window's times come with its lines.** `NewLines` returns the index of the first new line, and the check slices `times` from there. A window whose lines have no time is unverified, rather than judged on the times of the lines before it.
- **`within` is per item.** The issue names the gap between two particular lines, so an item carries its own, and the first item of a sequence cannot.
- **`within` is a matcher field, and the positional rule is in both validators.** The schema types `within` as a whole number, 1 to 600. A JSON schema cannot say "not the first item", and a separate definition would only hide the reason behind "additional properties are not allowed", so `Plan.lua` and `ct.py validate` give the clear message, as they do for the `id` and `bag` fields of a state probe.
- **Plan revision 3.** `Plan.REV`, `ct.py PLAN_REV` and `PLAN_NEEDS` move together, so `compile` writes `needs: 3`. An older CheckThat would otherwise ignore `within` and pass a check it never timed.

## Risks

- A source whose times are not in order (the game's clock runs back after a /reload) could pair two lines wrongly. The check then judges the gap it can read and answers unverified, never a silent pass, because both lines must still be in order and timed.
- A log whose oldest line has no time makes the whole window untimed, which is the same rule `ReadLog` already uses for the boundary.
