# Design

## Context

Group B of the open issues. Four independent pieces share one change so the docs and test plan move once. Codex reviews the design for UX gaps and the code for ways to break it, both before archive.

## Goals / Non-Goals

**Goals:**
- Remove a mistaken category without losing any recorded result.
- Pick categories of any plan size, on the card and on Home.
- Verdicts from the keyboard, off by default.
- Report evidence that matches what the player did.

**Non-Goals:**
- A `/ct` command to remove a category (menu only; a slash form can follow when asked).
- Removing a category that holds results. Rerun and end the run cover that.
- Key bindings for Undo, Partial-only flows or navigation.
- Per-attempt stack matching in the `/ct log` report (tool report only).
- Reaching every row item when the game has no context menu: https://github.com/NullStatBonus/wow-checkthat/issues/84.
- A reopened marker when Undo removes a step's only attempt: https://github.com/NullStatBonus/wow-checkthat/issues/85.

## Decisions

1. **Remove only a clean category.** `Run.Deselect(run, ctx, id)` succeeds when every step of the category has no finished attempt. An open (unfinished) attempt is dropped. Otherwise it returns nil and a reason (`has results`). The last picked category cannot be removed (`last category`). It sets the steps back to `deselected`, calls `reorder` and keeps the viewed step. If the viewed step leaves, the view moves to the next pending step. History entries of the category cannot exist, since there are no results. This answers the issue's "ask first when attempts exist": attempts that hold results refuse, so no question is needed.
2. **Menu item.** "Remove from run: <title>" shows in `Card.CategoryItems` only when the category is picked, has no resolved step, no step with an attempt, and other categories stay picked. The reason line shows otherwise through the same text path as Add to run.
3. **A Picker window, not a Tracker mode.** `UI/Picker.lua` copies the Tracker's row, wheel and page-button pattern (14 rows) with a checkbox per row. The card start screen keeps inline checkboxes up to 8 and shows a "Choose categories" button above 8, plus the count picked. The picker writes through `App.SetPick`, as the inline boxes do. Esc closes it. Start run stays off while none is picked.
4. **Home pages the list.** AceConfig needs a fixed set of controls, so the 24 toggles stay, with an offset and Previous and Next buttons that show when the plan has more than 24. The hidden-slot pattern already exists (`SLOTS`).
5. **Bindings through XML.** `Bindings.xml` declares CHECKTHAT_PASS, CHECKTHAT_PARTIAL, CHECKTHAT_FAIL and CHECKTHAT_SKIP, each calling a global function that runs the same `App.Verdict` path as the button click (note taken from the box, same after-verdict refresh). No default key. The functions do nothing when the card is hidden or no run is active, and print why. Keys never reach a protected action.
6. **Stacks per attempt.** In `tools/ct.py` `stack_hits` runs for every attempt, not for the last one of a failed step. A recovered failure's stacks appear in JUnit `system-out` and in JSON on that attempt, keeping the "time also fits another attempt" label.
7. **Reopened evidence.** A step that is pending with attempts shows "awaiting retry" and evidence `none` in the table, as JSON already calls it "not run".
8. **One new-attempt path.** `App.Verdict` arms `Errors.StepStarted` when it opens an attempt, using the same before-and-after attempt count as `App.Begin`. Both call one local helper.

## Risks / Trade-offs

- Key bindings fire while the player types in chat or the note box? The game suppresses bindings while an edit box has focus. A test checks the functions only act with a visible card.
- A held key can record a verdict twice. The second press records on the next step: same as double click. Accepted.
- Home paging adds state to the options tree; `test_options` validates it with AceConfig's validator.
