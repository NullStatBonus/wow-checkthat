# Design

## Context

- `collect_shots` (`tools/ct.py`) loops runs, steps and attempts and copies files with mtime in [start-2, end+2]; an unfinished attempt gets 900 s. It skips a file already copied (so "copied" is not "matched") and returns an int that `cmd_collect` sums over screenshot folders. `run_shots` lists `shots/`.
- `Run.Undo` removes the last attempt and sets the verdict to pending; `Run.Rerun` loops every step of the category; `Run.Deselect` clears attempts. `step_table` infers "reopened" from a pending verdict plus a finished attempt. `classify`/`SKIP_WHY` in the json and junit reports give such a step "skipped / not run".
- `Tracker.RowMenu` calls `A.ContextMenu` (MenuUtil, then UIDropDownMenu; it does not try the second when the first errors) and falls back to `items[1][2]()`. `test-runner-ux` and `tests/test_tracker.lua` encode that fallback. `docs/contracts.md` records that both menu APIs exist on Era, so the fallback shows only on a client that has neither, or when the menu errors.
- `Tracker.Refresh` reuses one `Button` per row (swatch at x=2, label at x=18, 110 px label, 215 px detail), `MAXROWS` 14, `offset` paging. Esc closes the window through `UISpecialFrames`.
- `Run.order` holds only offered steps; deselected and inapplicable steps are not in it.

## Goals / Non-Goals

**Goals:**
- No silent screenshot drop; the tester sees count, nearest attempt and gap, without old unrelated screenshots swamping it.
- An explicit reopened marker in the run record, tolerated when absent or stale, shown the same in every report.
- Every row action reachable on every client.
- See and jump to a category's steps in place.

**Non-Goals:**
- Keeping a `screenshot: true` step's window open until the next step.
- Saving expanded rows across reload or relog.
- The card's Run menu (`Card.lua`) has the same first-item fallback. It is left as it is; the card shows only on the same clients, and the fix here is not shared code.
- Network-mount clock skew: tracked in https://github.com/NullStatBonus/wow-checkthat/issues/95. `--verbose` exposes the gap meanwhile.
- No debug log line when Undo reopens a step, so a plan cannot assert `reopened`: https://github.com/NullStatBonus/wow-checkthat/issues/100.

## Decisions

1. **Unmatched screenshots.** One pass over the files. A file inside any attempt window is matched whether or not it is copied now; the rest are unmatched only when within 3600 s of some attempt (constant in `ct.py`), so a long-lived Screenshots folder is not counted. Nearest attempt: smallest gap to [start, end] (unfinished attempts use start+900); ties go to the earliest run id, then plan order. With `--wow`, prefer runs whose `client` matches the folder's client; with no match, any run. `--all-shots` copies to `runs/<id>/unassigned-shots/`, a sibling of `shots/`, so `run_shots` needs no change. `collect_shots` returns (copied, unmatched list); `cmd_collect` sums over folders. Flags are read with `getattr(a, name, False)` since tests build bare args objects.
2. **Reopened marker.** `rec.reopened = true` is set in `Run.Undo` and in `Run.Rerun` only for steps that had a result (inside the `verdict ~= "pending"` branch); `UndoLast` gets it through Undo. It is cleared where an attempt finishes (`Run.Verdict`) and in `Run.Deselect`. `FORMAT_REV` goes 1 to 2. A 0.16 client may continue the run and never clear the flag, so readers trust it only on a pending step: `step_table`, `classify` and `run_model` treat a step as awaiting retry when its verdict is pending and (flag set or a finished attempt exists). Absent key means unknown, not false. The results string stays version 1.
3. **Menu fallback.** `Adapter.ContextMenu` falls through to `UIDropDownMenu` when `MenuUtil` errors, and returns false only when both fail. Then `Tracker` shows a small frame of buttons under the row, one per item, with the black background and opacity rules. It closes on a pick, on Esc, or on hiding the window. Esc is taken by the frame (keyboard enabled while shown, `OnKeyDown` handles Escape and does not propagate), not by `UISpecialFrames`, so it does not close the window behind it; the task list verifies that against `UIParent.lua` and records it in `docs/contracts.md`. No click-elsewhere catcher: a stray click on another row replaces the list. Because Era has both menu APIs, the list is proven by unit tests with the APIs removed, not by a manual check. Blizzard has no standard menu to reuse where neither API exists, so a button list is the fallback shape.
4. **Expand.** Each category row keeps its click for the menu. A small expand button at the row's left toggles a set of expanded ids held in `Tracker`, reset when the shown run id changes. `App.CategorySteps(id)` takes the steps from the run's plan sections (not `run.order`), and returns `{ id, title, word, mark, offered }`. New step-result words are `L[]` strings; the mark glyphs stay in `UI/`. A step that is not for this client reads "not for this client". `Tracker.Refresh` builds one flat list of category and step rows, then pages over it. Each row has a kind: its own click (menu for a category, `App.ShowStep` for a step), tooltip, arrow and expand-button visibility, all reset on every Refresh since row frames are reused. The step label is indented by shortening the label width, not by moving the swatch. `ApplyAppearance` fades the new textures. `App.ShowStep(id)` resolves a step id only (no category fallback and no "ambiguous"), does nothing for a step that is not offered, never picks a category, and then refreshes the card. Orphan step rows at the top of a page get no header; the paging line counts rows, not categories.
5. **Reports.** `run_model` gains `awaitingRetry`; `classify` reports it as reason "awaiting retry" in json and junit, in the table and in the viewer.
6. **Debug log.** `tracker expand <category>` and `tracker collapse <category>` lines. Expanded rows are not a setting, so the debug report has no new value.

## Backlog check (2026-11-24)

Issues #84, #85, #86 and #88 are unchanged and still open; none has a "Backlog change" comment. The regrouping does not touch this change:
- #90 and #91 rework `find_sv` and the decoder, not `collect_shots`. Both edit `cmd_collect` and `tools/test_ct.py`, so expect a small merge, not a conflict in logic.
- #92 plans `targetVersion` with a `FORMAT_REV` bump "after" this change. This change takes revision 2; #92 takes the next one.
- #26, #61, #73, #74, #11, #18 and #9 are closed. None was a dependency here.

## Risks / Trade-offs

- A plan with hundreds of steps: default collapsed and paging keep the window fixed in height; an expanded large category pages.
- Raising `FORMAT_REV` makes older CheckThat versions read the run as newer; `formatRev` rules already cover it.
- The fallback list cannot be seen on Era or Camelot, where both menu APIs exist; only tests and a client with neither would show it.
- Counting only files within an hour of an attempt hides a screenshot taken later than that; `--all-shots` has the same limit.
