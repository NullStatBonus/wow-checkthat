## Context

See proposal.md - Why. The card header holds the title, step counter, `<`, `>`, collapse and close. It has no room for another button. A finished run already shows Main window and Export results. `Adapter.Confirm` wraps a native Yes/No popup with Escape to cancel. `/ct log clear` uses it.

## Goals / Non-Goals

**Goals**
- One code path for the menu item and `/ct end`.
- An ended run keeps every recorded verdict and is clearly marked ended.

**Non-Goals**
- A minimap or addon-compartment button. The issue names it as a separate question. Open a GitHub issue for it when this change is approved.
- Reopening an ended run.
- A bulk "end all runs" action.
- Deleting an ended run or its results.

## Decisions

1. **Header menu, not a seventh button.** The "Run" label opens a menu with "End run...". Use `MenuUtil.CreateContextMenu` when it exists, else `UIDropDownMenu` through `EasyMenu`-free manual init, else a plain "End run..." button in the same slot. The choice checks function existence, never the client name. The adapter owns the game calls. Blizzard's objective tracker uses a context menu for secondary actions. Alternative rejected: a button in the verdict row beside Undo, because a mis-click lands next to Pass and Fail.
2. **Always confirm.** An open attempt can already hold evidence. Text: "End this run? Your recorded results will be kept. You cannot resume this run." Reuse `Adapter.Confirm`. Escape or a missing popup leaves the run active. The accept callback re-checks that the same run is still current.
3. **State: `run.endedAt`.** Optional timestamp. One `Run.Touch` bump on end. `Run.End(run, now)` sets it, drops the open attempt's pending state, and returns false if already ended. Older saves have no field, so they read as not ended.
4. **Ended means closed.** `Run.Verdict`, `Run.Undo`, `Run.UndoLast`, auto-settle and reload resume all return early for an ended run. Starting the plan again makes a fresh run, as today.
5. **Results stay as recorded.** Pending and unverified steps keep their state. No "skipped, run ended" verdict: it would invent a verdict the player never gave. Counts and progress stay honest ("3 of 8 resolved").
6. **Card state.** An ended run shows the existing finished-run view with a "Run ended" line, Export results and Main window. Resume and Undo are hidden. The collapsed strip shows "Run ended".
7. **Export and report.** `Run.Export` copies `endedAt`. The `/ct log` report and `/ct status run` print an ended line. The debug log gets `run ended <runId>`.
8. **Command.** `/ct end` pairs with `/ct start`. With no run it prints "There is no run." With an ended run it prints that the run already ended.
9. **Combat.** Ending needs no protected call. Clear the secure button's desired state at once. Apply protected changes after combat as today.

## Risks / Trade-offs

- **An accidental end is permanent.** The confirmation and the menu placement away from verdict buttons limit this. Plans stay imported, so a fresh run costs one click.
- **Menu API differs by client.** The fallback button keeps the action reachable. Tests cover each path with the fake client.
- **Assumption.** Undo and Resume stay off after end. This favors a simple, testable rule over a recovery path. Revisit if players ask.
