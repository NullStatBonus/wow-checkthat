# Design

## Context

`Evidence.NewLines` rejected a snapshot tail found twice. A full log that holds the lines of an earlier identical run always does.

## Goals / Non-Goals

**Goals:**
- A positive log check can pass after a repeated run; an absence or count check stays unverified.
- Undo and stale macro presses leave evidence in the log and the run record.

**Non-Goals:**
- Measuring screenshot skew on a network mount (#95). It needs a real mount.

## Decisions

1. **Last match wins, never exact when ambiguous.** The last match may sit after the true boundary and hide lines. `exact = false` makes every absence or count check unverified, so a missed line only costs evidence.
2. **`macroStale` is counted on the step the card showed** of an open run, and never on an ended run. A key that is absent means none. It is additive: formatRev 4, results string stays format 1.
3. **Undo logs in `App.Undo`**, beside the rerun line, using the id `Run.UndoLast` returns.
