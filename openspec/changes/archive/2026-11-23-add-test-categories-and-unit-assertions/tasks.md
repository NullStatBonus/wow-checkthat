# Tasks

Every behavior task lands its own test. Break the behavior once, see the test fail for the expected reason, restore it, then run `luajit tests/test_<module>.lua`. Run `make test` at the end of each group.

## 1. Plan format: categories and operators (Model/Plan.lua, schema, tools)

- [x] 1.1 Add `categories`, step and section `category`, `Plan.Categories`, section fallback and category on `Plan.Steps` entries. Verify with `tests/test_plan.lua`: unknown id, step in no category, section default, no categories.
- [x] 1.2 Extend `Plan.OPS` and the value shapes (`between`, `in`, `approx` with `tolerance`, `type`), add `kind: fact` with `which`, add `count` and source `quiet`. Verify with `test_plan.lua` scenarios from the test-plan-format delta.
- [x] 1.3 Mirror all of 1.1 and 1.2 in `schema/test-plan.schema.json` and `tools/ct.py` (`validate`, `merge_sections`). Verify with `tools/test_*.py` and a test that fails when `Plan.OPS`, the schema enum and the tool list differ.
- [x] 1.4 Add `cases` expansion with `{{name}}` to `tools/ct.py`; the addon rejects `cases`. Verify with Python tests: three cases, unknown placeholder, duplicate suffix, import of an unexpanded plan.
- [x] 1.5 Update `docs/authoring-plans.md` (one example per assertion type and one for `cases`) and the skill files (the spec sync happens at archive); check that `ct-test-plan` and `ct-verify` skill files name the new kinds. Verify with `make test` and `make check`.

## 2. Evidence: typed facts, counts, quiet sources (Model/Evidence.lua)

- [x] 2.1 Add `Evidence.ParseValue`, the shared operator table and `Evidence.CheckFact` with `which`. Verify with `tests/test_evidence.lua`: range, tolerance, type, `in`, `matches`, never-arrives (unverified), contradiction (fail), wrong shape.
- [x] 2.2 Add `count` for `log` and `fact` and quiet-source absence. Verify with `test_evidence.lua`: exactly 2 with two, three, one; zero on quiet readable; zero on unreadable; rolled log.
- [x] 2.3 Extend `state` checks with the new operators. Verify with a `global-value` between and approx test.
- [x] 2.4 Make `Evidence.Preview` and card labels handle the new kinds (generic label per kind when `label` is absent). Verify with `test_evidence.lua`.
- [x] 2.5 Document in `docs/features.md` (with debug log lines), `docs/debug-logging.md` and `docs/contracts.md` (value parsing rule).

## 3. Lua error capture (Core/Adapter.lua, Model/Errors.lua)

- [x] 3.1 Review the Classic Era and Camelot client use of `geterrorhandler` and `seterrorhandler`, and how BugGrabber chains. Record what was measured in `docs/contracts.md`. Verify the section names its sources. (Done: BugGrabber's source showed that it makes `seterrorhandler` a no-op, so a task was added to read its counters: 3.6.)
- [x] 3.2 Add `Adapter.HookErrors`, guarded and in `pcall`, returning nil when the functions are missing. Verify with `tests/test_layers.lua` (no game global outside the adapter).
- [x] 3.3 Add `Model/Errors.lua` and `tests/test_errors.lua`: bounded list, cut message, rate limit with one debug line, no record without a run, earlier handler always called, handler that raises, re-hook when replaced. Add the file to both TOC files in the same order (`make check`).
- [x] 3.4 Show the error count and hook state in the debug report (`/ct log`). Verify with `tests/test_log.lua`.
- [x] 3.5 Add the harness fakes (`geterrorhandler`, `seterrorhandler`) and run `test_smoke` with the real libraries.

- [x] 3.6 Detect a blocked hook (read the handler back after setting it) and, when blocked, record BugGrabber's counter rises as errors (`Errors.Sample`, `Errors.Rebase`). Sample before a step opens, before a result is judged, in the automatic settle and on the card's check refresh. Verify with `tests/test_errors.lua` and `tests/test_selftest.lua` (an error counted by BugGrabber fails the no-error step).

## 4. Run model: selection, state, trigger, rerun (Model/Run.lua, Model/App.lua)

- [x] 4.1 Store `categories`, `cat` and `selected` in `Run.New`; add the `deselected` verdict and the `Run.Counts` field; add `Run.Normalize` for old runs. Verify with `tests/test_run.lua`: picks, order, counts, old run fixture (anonymized copy of a saved run).
- [x] 4.2 Add `Run.Select` (add a category, keep current step and history). Verify: order stays in plan order, Undo still works.
- [x] 4.3 Add `Run.CategoryState`, `Run.OverallState`, `Run.Trigger` and `Run.Rerun`. Verify with the scenarios in the test-categories delta in a new `tests/test_categories.lua`, including only-skips, retry passes and rerun keeps attempts.
- [x] 4.4 Add `App.CategoryChoices`, `App.Start(addon, picks)`, `App.Trigger`, `App.Rerun`, `App.Categories`, with debug log lines. Verify with `tests/test_app.lua`: nothing picked, mid-run add, trigger with a hidden card, no run.
- [x] 4.5 Show categories and deselected steps in `App.Status`, the past-runs row and the report. Verify with `test_app.lua`.
- [x] 4.6 Update `tools/ct.py` report and results decoding: category rollup, deselected apart from unverified; Python copy of the state rule checked against a shared fixture. Verify with `tools/test_*.py`; update `docs/harvesting.md` and `ct-verify`.

## 5. Slash commands (Core/Slash.lua)

- [x] 5.1 Add `/ct categories`, `/ct run <name>`, `/ct rerun <category>` with usage lines, no-run lines and surplus-input rejection; update `/ct help runs` and the About list. Verify with `tests/test_slash.lua`, `test_combat` (trigger in combat changes no protected frame) and `tests/test_readme.lua`.
- [x] 5.2 Add the locale strings as whole sentences. Verify with `tests/test_locale.lua`.
- [x] 5.3 Update README command table and `docs/features.md`.

## 6. Tracker and category choice (UI/Card.lua, Options/Options.lua)

- [x] 6.1 Review Blizzard UI source and popular addons for segmented progress bars, tooltips and context menus. Record the chosen pattern and the fallback in `docs/contracts.md`. Verify the section lists the sources read.
- [x] 6.2 Replace the progress bar with the tracker: segments, overall bar, caption, tooltip, opacity rules, 8 segment cap, collapsed state, click to trigger, category menu. Verify with `tests/test_card.lua`: colors per state, no fill at zero opacity, caption words, single-category card keeps the plain bar, more than 8 categories. (Segments are textures and take no click; the Categories list and a rerun question replaced click-to-trigger, after the Codex review.)
- [x] 6.3 Add the category list with state words and counts to Home "Current run". Add the `multiselect` choice to Home "Start a run" and to the card start screen. Verify with `tests/test_options.lua` (AceConfig validator) and `test_card.lua`.
- [x] 6.4 Update `DESIGN.md` sections 3 and 4 with the tracker, its colors and the caption rule.

- [x] 6.5 Add the Categories window (`UI/Tracker.lua`, both TOC files), the card's Categories control and `/ct tracker`; the row menu uses `Card.CategoryItems`. Verify with `tests/test_tracker.lua`: twelve and twenty categories, scrolling, colors and words, row menu, fallback, position, opacity.
- [x] 6.6 Log the error handler state once when it changes (`handler current|replaced|blocked|off`), so a saved log says which way errors were read. Verify with `tests/test_errors.lua`.

## 7. Plans and self-test

- [x] 7.1 Add declared categories and steps to `plans/selftest.yaml`: typed fact (needs `/ct fact` to report a value), a count, the error source (a step that expects an error line from a deliberate, safe error the player triggers by copying a command, and a step that expects none). Verify with `tests/test_selftest.lua` and a compile of every plan under `plans/`.
- [x] 7.2 Check every plan in `plans/` still compiles and decodes with sections as categories. Verify with `make test`.

- [x] 7.3 Make the error lines unique (time and counter), so a list of one repeated error does not make "no Lua error" unverified (seen in a real run). Make "Export results", "Count exactly" and "No Lua error" automatic: a check that something did not happen is allowed on an auto step with a timeout and is judged when it ends (fails at once if broken). Verify with `tests/test_errors.lua`, `tests/test_run.lua`, `tests/test_plan.lua`, `tests/test_selftest.lua` and `tools/test_ct.py`.

- [x] 7.4 Add `cap` to log sources: a bounded log below its cap has never rolled, so a boundary at the snapshot position is exact even when the last lines are alike (a real run left three identical old error lines and kept "No Lua error" unverified). Verify with `tests/test_evidence.lua`, `tests/test_plan.lua` and `tools/test_ct.py`; the self-test plan declares `cap: 300` for facts and `cap: 100` for errors.

## 8. Docs and manual checks

- [x] 8.1 Update README (features, commands, Good to know), `docs/features.md`, `docs/listing.md` (summary and features), and `docs/test-plan.md` (unique section numbers in order, one player action per check, a `Check:` line and a `Log:` line).
- [x] 8.2 Verify `/ct log` reports the picked categories and the error hook state; add the missing lines if not.

## 9. Backlog

- [x] 9.1 Run `gh issue list`. Open issues for: time windows between lines, removing a category mid-run, a WoWUnit result bridge. Write the issue numbers into design.md Non-Goals. Issue text: gap, code involved, approach; no personal names.

## 10. Integration

- [x] 10.1 Run `make test` and `make check`; run `openspec validate add-test-categories-and-unit-assertions --strict`.
- [x] 10.2 Run the self-test plan's new steps in game through `/ct` and read the copied `/ct log` or saved variables before asking the player for anything else. (Done over several runs on Forever 1.60.1.71037 with BugGrabber loaded: the last run passed 14 of 15, and the one failure was a deliberate double Run click. Not seen: BugGrabber disabled.)

## Workflow follow-up

- Offer the test plan skill once after the tasks are done (project guidance).
- Archive with `/opsx:archive`: sync specs, bump both TOC files to 0.10.0, add the `## 0.10.0` CHANGELOG section (New, Changed), then commit, and tag `v0.10.0` as in `docs/publishing.md`.
