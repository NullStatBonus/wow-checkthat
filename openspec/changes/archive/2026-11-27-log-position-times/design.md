## Context

A position is `{ n, tail }`: the log length and its last 12 lines when the attempt opened. `NewLines` finds the tail in the current log. In a full ring the tail is searched; several matches, or a tail of mostly equal lines, make the boundary inexact, and an absence or an upper count is then unverified.

## Decisions

- **Times as part of a line's identity.** Logs of format `entries` hold `{ t, msg }`. Comparing `t` with `msg` makes a repeated block distinct unless it was written at the same times. A log's clock does not run back, so when the tail spans more than one time value, the same tail cannot appear again later in the log: it is found at most once, and that place is exact. A tail all at one time (a burst in one tick) gives no such proof and keeps the old rules.
- **Clock that ran back.** `GetTime` restarts with the computer, so a log kept across sessions can step back. Two places found is then possible and stays inexact. One place found after a step back is still the only one with those times.
- **Additive.** `times` is a new optional key in a saved position; a position without it (saved by 0.21.0 or earlier) and a current log without times use the old rules. `Run.FORMAT_REV` goes to 7. Positions are never exported, so the results schema does not change.
- **Proof by model.** A randomized ring model with repeated blocks and a clock that sometimes stands still checks that an exact window is always every new line, and that times prove more boundaries than the old rule.

## Non-Goals

- Idea 2 on the issue, a `replay-flow` report of steps near the cap boundary, is filed as #260.
- Logs of format `strings` carry no times; they keep the old rules.
