# Tasks

## 1. Screenshots (#88)

- [x] 1.1 Rework `collect_shots` as in design decision 1: matched whether or not copied, unmatched only within 3600 s of an attempt, deterministic nearest attempt, client preference with `--wow`, return (copied, unmatched). Verify with `tools/test_ct.py` cases: just inside, just outside, unfinished attempt, an old file that is not counted, two collects in a row, a tie, two clients.
- [x] 1.2 Print the count in the summary; add `--verbose` and `--all-shots` (`unassigned-shots/`), read with `getattr`. Verify the flags in tests, including the no-run case, and that `run_shots` and the report do not show `unassigned-shots`.
- [x] 1.3 Update `docs/harvesting.md` (Screenshots) and the README. Verify `make test`.

## 2. Reopened marker (#85)

- [x] 2.1 Set `rec.reopened` in `Run.Undo` and in `Run.Rerun` only for steps that had a result; clear it in the attempt finish and `Run.Deselect`; raise `Run.FORMAT_REV` to 2. Verify in `tests/test_run.lua`: Undo of the only attempt, Rerun with an untouched step, Remove from run, retry finishing.
- [x] 2.2 Add the key to `schema/run-results.schema.json`, the revision 2 row and the `Current:` line to `docs/results-format.md`, and a note in `docs/features.md`. Update the `formatRev == 1` checks in `tools/test_ct.py` (run and attempt) and the page check. Verify `tools/test_ct.py` passes.
- [x] 2.3 Make `step_table`, `run_model` and `classify` (json, junit, viewer) show "awaiting retry" for a pending step that is flagged or holds a finished attempt, and ignore the flag on a non-pending step. Verify with runs with the flag, without it, and with a stale flag on a passed step. Update `docs/harvesting.md` and `skills/ct-verify/SKILL.md` if they describe the old inference.

## 3. Menu fallback (#84)

- [x] 3.1 Make `Adapter.ContextMenu` fall through to `UIDropDownMenu` when `MenuUtil` errors. Verify in the adapter tests with a failing `MenuUtil`.
- [x] 3.2 Check `UIParent.lua` and popular addons for how Esc and `UISpecialFrames` interact with a child frame; record the finding in `docs/contracts.md`.
- [x] 3.3 Replace `items[1][2]()` in `Tracker.RowMenu` with the button list. Replace the test "without a menu a click runs the main item" and the comment in `Tracker.lua`. Verify in `tests/test_tracker.lua` with both menu APIs removed: every item shows, none runs, a pick runs and closes, Esc closes only the list.

## 4. Expand (#86)

- [x] 4.1 Add `App.CategorySteps` (from the plan sections, with the words for each result and for not picked and not for this client) and `App.ShowStep`. Verify in `tests/test_app.lua`: plan order, an unpicked category, an inapplicable step, a step named like a category, an ended run, and that `ShowStep` never picks a category.
- [x] 4.2 Add the expand button, row kinds, flat paging, indent and appearance in `Tracker.lua`, reset the set on run change, and log `tracker expand` and `tracker collapse`. Verify in `tests/test_tracker.lua`: expand, collapse, a reused row frame changing kind, paging count, step click shows the step and changes no result, zero opacity draws nothing, the log lines.
- [x] 4.3 Add `L[]` strings for the new text. Verify `tests/test_locale.lua` and `tests/test_options.lua` pass.
- [x] 4.4 Update README (one or two lines, including the `/ct tracker` row checked by `tests/test_readme.lua`), `docs/features.md`, `docs/listing.md`, and `docs/test-plan.md` with short manual checks using the next free numbers (4.12 for the collect check, 5.15 and up for Categories): expand and jump; collect with a screenshot step inside a window, which also covers the mount time skew in the issue named under Non-Goals. The no-menu list has no manual check. Verify `make test`.

## 5. Integration

- [ ] 5.1 For each new behavior, break it, see the focused test fail for the expected reason, restore it. Verify `make test` and `make check` pass.

## Workflow follow-up

- Archive the change; bump both TOC files to 0.17.0 and write the `## 0.17.0` changelog section at archive.
- Commit with "Closes #84, closes #85, closes #86, closes #88" (each issue needs its own keyword); list the manual checks as PR checkboxes.
