# Design

## Context

AceConfigDialog calls a `confirm` function when the player clicks the button, so the function can log that the question was asked. Cancel gives no callback; the missing `run opened` line shows it. The game's `[combat] hide; show` state driver shows the Run button every 0.2 seconds out of combat, which the hide guard then undoes.

## Goals / Non-Goals

**Goals:**
- A plan can check each question, export and report from the log.
- No repeated log line from the Run button.

**Non-Goals:**
- A log line for the list contents (display only; see issue #49 for an ended marker).

## Decisions

1. **Ask when another run is active, not when the target is unfinished.** `App.OpenAsks(id)` is true when this character has an unfinished current run that is not the run asked for. Opening the current run again asks nothing: it takes nothing from the card.
2. **Two question texts.** Replacing a run keeps its text. Viewing an ended run says the current run stays.
3. **Release the state driver while the button is not wanted.** The driver is the cause of the 0.2 second loop. Unregister it out of combat when a step has no commands. Register it again when a step wants the button. `pendingMacro` already moves all of this out of combat. Alternative: only de-duplicate the log. Kept as a fallback.
4. **Log the Stored line with the report.** One line proves the report ran and held the stored counts.

## Risks / Trade-offs

- [The state driver cannot be tested without a client] → the smoke test checks the calls; the in-game plan checks the log.
