## Context

`run_model` and `classify` already give one result for each step (pass, partial, fail, unverified, skipped), holding a pass to its evidence. `latest_runs` lists refused or unreadable runs. Collected runs name their plan only by `planDigest`; the plans are in the copied CheckThat saved variables (`CheckThatDB.planStore`).

## Goals / Non-Goals

**Goals:**
- Compare two runs, and many runs, with the same judgement as `report`.
- Never treat a changed or unknown plan step as comparable.

**Non-Goals:**
- Part B of issue 92: the addon records `targetVersion` (a `FORMAT_REV` bump, a schema key, a version bump) and, optionally, the embedded library versions. It changes `CheckThat/` and ships in its own change. The issue stays open for it.
- Charts, HTML dashboards, changes to the in-game UI, merging runs, guessing a version from a plan title.

## Decisions

1. **Judgement.** Both sides go through `run_model`. OK is pass or partial, bad is fail or unverified. ok to fail is `regressed`, ok to unverified is `newly-unverified`, bad to ok is `fixed`, bad to bad is `still-failing`. `--strict` fails on `regressed` only, as the issue says.
2. **Skipped is not comparable.** pending, skip, deselected, inapplicable and reopened steps all classify as skipped. Any skipped side gives `not-comparable`, so a client difference never shows as a change.
3. **Same step.** Equal digests mean equal steps. Else both runs' stored plans must name the step, and the fingerprint (sha1 of the canonical step JSON, whole step) must match. A fingerprint that differs gives `not-comparable` (`~`). A missing plan or step gives `not-comparable` (`?`) and a warning. We do not guess "probably the same". The cost: without collected saved variables, a diff across a plan edit shows added, removed and not-comparable only.
4. **Trend groups** by addon and plan title, so plan edits stay in one table, and judges each cell against the newest run in the group. A step is flaky when comparable cells hold both ok and bad results. `--by` names a column by the run's client, character, build or CheckThat (writer) version; columns are numbered because ids are long.
5. **Unfinished runs** (no `endedAt`) are left out of trend and refused by diff unless `--include-open`.
6. **Newer format.** `diff` exits 2 and names the run. `trend` leaves it out and lists it on stderr and in the json warnings. Exit codes: diff 0, 1 (strict regression), 2 (error); trend 0 or 2 (no run).
