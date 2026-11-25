# Design

## Context

Change `macro-follow` keeps the CT macro on the current step. `Card.MakeMacro` and `Card.FollowMacro` build the body from `App.MacroText`, which the Run button also uses. The adapter writes the macro; a macro cannot make the game skip its other lines.

## Goals / Non-Goals

**Goals:**
- A press shows which step the macro was written for, so a plan and a reviewer can see presses that are out of sync.
- Run and the macro are distinguishable in the log.

**Non-Goals:**
- Stopping the commands of a stale press. The game runs every macro line.
- A field on the run record for stale presses. Evidence is the debug log and needs debug recording. A run field is tracked in #120.

## Decisions

1. **The marker lives in one body builder in `Card`, never in `App.MacroText`.** The Run button uses `MacroText`: a marked Run would log `macro run` and the macro could not be told from Run. Existing combat tests compare Run's text to `MacroText`.
2. **The marker is the first line.** A step command such as `/ct next` could move the step. Compared first, a correct press never reads as stale.
3. **The builder returns the body, the step, and whether the commands fit.** The marker and the commands must fit in 255 characters. `Plan.MacroAllowed` checked the commands only. The card hint and the written body use the same builder so they agree. The combined body is not re-checked against the allow list: other addons' plans have no `/ct` in it.
4. **`App.MacroRun(id)` does the comparison**, so the logic is plain Lua. It uses `App.Current()`, the source `FollowMacro` uses. Match: log only. Mismatch: log `macro stale <id> card <current id>` and return one chat line.
5. **A macro with no step open** (no run) keeps the plain body `/ct status`, with no marker.
6. **Version stays 0.20.0.** The follow change is unreleased in the same pull request, so the changelog line grows.

## Risks / Trade-offs

- [The marker uses about 20 characters plus the step id] → a step near the limit falls back to `/ct status` sooner. Step ids are short in practice.
- [Evidence needs debug recording] → plans turn it on first. A press with recording off is not seen.
- [A stale press still runs its commands] → accepted. The chat line tells the tester at once.
