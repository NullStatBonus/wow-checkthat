# Design

## Context

`Card.Refresh` runs on every step change and calls `setMacro` (the Run button). `PLAYER_REGEN_ENABLED` already calls `Card.Refresh` (`Core/Addon.lua`). `Card.MakeMacro` creates or edits `CT` through the adapter and records `ui.macroName` and `ui.macroBody`, so it never overwrites a macro the player changed. `App.MacroText` builds the body and checks the allow list and the line limit. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- One macro button and one result key play a whole plan.
- Reuse `MakeMacro` and the existing refresh path. No new event.

**Non-Goals:**
- Default key bindings for the result keys. The rule stays: no key set by default.
- A plan field such as `no-macro`. The card line covers the player-visible need.
- A second macro for `/ct next` and `/ct back`. Result keys already advance the run.
- Protected actions in the macro. Commands stay on the allow list.
## Decisions

1. **Hook in `Card.Refresh`, next to `setMacro`.** Every step change already passes there, including the Categories jump, Undo and a new run. Alternative: hook each caller (Go, verdict, Undo). Rejected: easy to miss one.
2. **Skip when nothing changed.** Refresh runs often. Compare the wanted body with `ui.macroBody` and edit only on a difference, so the log has one `macro set` line per real change and the game gets no needless edits.
3. **Split `MakeMacro` into `SyncMacro(silent)` and the slash wrapper.** `/ct macro` keeps its chat line; follow mode is silent. Follow creates the macro when none is owned, as `/ct macro` does, because the setting is an explicit opt-in.
4. **Combat: return without writing.** The sync compares the wanted body with the saved one, so the existing `PLAYER_REGEN_ENABLED` refresh writes once, for the step current at that time. No flag, no queue list.
5. **Length limit already enforced.** `Plan.MacroAllowed` refuses a body over 255 characters, so `App.MacroText` returns nil for it, like an over-long line count. A test pins this. The macro then holds `/ct status` and the card line says the step has no macro. The line shows only when the step has copyable commands, so a command-less step stays quiet.
6. **Setting `macroFollow` in the profile, off by default.** Turning it on calls `SyncMacro` at once. It logs `macroFollow on/off` and appears in the debug report beside `loginCheck`.
7. **No result command can enter the body.** `MacroText` only reads step actions and the allow list, which has no `/ct pass`. A test asserts this for every step of a fixture plan.

## Risks / Trade-offs

- [Macro slot full] → `CreateMacro` fails: print the existing message once, not on each refresh (set a flag until the setting toggles).
- [Player edits `CT`] → the body no longer matches `ui.macroBody`: stop following that macro and leave it alone. `/ct macro` makes a new one (`CT2`) as today.
- [Edit while the macro frame is open] → harmless; the frame shows the new text on next open.
- [Refresh runs in a loop] → decision 2 makes the sync idempotent.
