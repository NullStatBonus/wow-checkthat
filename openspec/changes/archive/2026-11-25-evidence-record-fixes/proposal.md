# Proposal

## Why

Four open gaps make a finished run read worse than it was: a repeated run loses its log evidence (#121), Undo leaves no log line (#100), stale macro presses are not on the run record (#120), and screenshot timing on a network mount is unmeasured (#95).

## What Changes

- `Evidence.NewLines` takes the last match when the saved tail appears more than once and marks the boundary not exact. A repeated run no longer reads "log rolled over; evidence lost".
- `App.Undo` logs `undo <step id>: reopened`. `plans/checkthat-0.17.yaml` step `ct17.undo` asserts it.
- A stale macro press adds one to `macroStale` on the step record the card showed. `Run.FORMAT_REV` is 4. `ct.py report` and `ct.py diff` show the count.
- Review findings fixed in the same change: #122 (a full ring reading the saved tail again is not exact), #123 (step and section ids must match `Plan.ID`; macro length in bytes; finite numbers), #124 (collect writes a revision atomically and keeps a damaged one aside; `diff` finds plans in collected files), #126 (browsing is not a revision change; a verdict on a step with a result needs Redo or Undo; a collapsed card still arms the step), #127 (closing the card releases the Run button driver).
- #95: `--shot-slack` already exists. The skew needs a measurement on a mounted game folder, so the issue stays open.
