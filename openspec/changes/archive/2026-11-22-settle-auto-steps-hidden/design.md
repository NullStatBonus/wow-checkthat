## Context

`Card.Show` starts `tick`, which calls `Card.AutoSettle`, `Card.UpdateChecks` and re-arms `A.After(0.5, tick)`. `tick` exits when the card is hidden, and `Card.AutoSettle` returns early unless `card:IsShown()` and `card:IsVisible()`. `App.AutoSettle(note)` and `Run.AutoSettle` are already model-side and read-only.

## Decisions

- **Loop stays in `UI/`, runs while an auto step is open.** Split `tick` into two parts. The settle part runs every 0.5 s while the current step is auto and open. The check-text part (`UpdateChecks`) still runs only when the card is shown. `UI/` may use frames and timers, and the note box is read from the card, so no new module is needed. (The issue suggests an app-owned ticker. Rejected as more code: the note read and `AfterVerdict` both live on the card.)
- **Start the loop from `Card.Show`, run start and resume, and any change to the current step.** The loop stops itself when no auto step is open and restarts on the next of those events. One `card.ticking` flag stays the guard so there is never a second loop.
- **Visibility gate.** Drop the `card:IsShown()` test. Keep a gate for a hidden game interface using the card's parent visibility (`UIParent:IsShown()`) and the Start screen check. Assumption: a hidden game interface still pauses settling, as the current spec says.
- **Note.** A hidden card keeps its note box text, so the existing note read works. The existing check that the box belongs to this step stays.
- **After a hidden result.** `Card.AfterVerdict` and `Card.Refresh` only touch the frame, which is safe hidden. `OnShow` already calls `Card.Refresh`, so the card opens on the next step. No new text.
- **Errors.** Keep the `pcall` and `ns.Log.Failure` path. An error never stops the loop.

## Risks

- A loop that never stops costs a little CPU. It stops when the run has no open auto step or has ended.
- `/reload` resume: the loop must restart after resume even if the card never shows. Covered by starting it from resume.

## Non-Goals

- Settling while the game interface is hidden.
- Any new card text for results recorded while hidden.
