# Design

## Context

See proposal.md for motivation. Today (`Model/Plan.lua`, `Evidence.lua`, `Run.lua`):
- Assertions are `log`, `log-sequence` and `state`. Only `log` has `absent`. A log check passes or is unverified; only an absence check can fail. A fact is one log line `[addon] key=value` in `CheckThatDB.global.facts`, so facts are matched as text.
- A run keeps `order` (applicable step ids), `steps[id].verdict` and `history`. A client-inapplicable step has the verdict `inapplicable` and no place in `order`.
- The card has a 3 unit progress bar of resolved steps. Home starts a run for a picked plan.
- Model code has no game globals. Game calls live in `Core/Adapter.lua`. Plans are data and nothing in them runs.

## Goals / Non-Goals

**Goals:**
- Categories, per-run choice, trigger and rerun, and a colored tracker (red, yellow, green, blue).
- The assertion types a unit test uses, with no other addon needed.
- Every existing plan, run and test keeps working.

**Non-Goals:**
- Removing a category from a running run (issue #60). Deselect means "not picked at start"; adding is supported.
- Auto steps with an upper-bound count (`exactly`, `max`): more lines can arrive after the step settles, so validation rejects them, like absence checks.
- Time windows between lines. Debug lines carry no time, so "within 2 seconds" has no evidence. Tracked in issue #59.
- Mocks, spies and stubs. The addon under test reports calls as facts, and `count` judges them.
- Running plan text as code, or any input. Triggering selects a step; the tester still clicks.
- A bridge from WoWUnit results (issue #61).

## Decisions

### D1. Category is an id, with the section as the fallback
`Plan.Categories(plan)` returns the declared list, or one entry per section. `Plan.Steps` adds `category` to each entry. Compile merges a section's `category` into its steps, like `requires`. Validation requires every step to resolve when categories are declared.
*Alternative:* require `categories` in every plan. Rejected: it forces edits to every plan, and a section is already a category for most plans. Declared categories stay possible for cross-cutting groups such as "smoke".

### D2. A run stores categories, the step map and the picked set
`run.categories = {{id,title}...}`, `run.cat[stepId] = id`, `run.selected[id] = true`. The run is then complete without its plan, so the report tool and the tracker need no plan lookup. A run without these fields (saved before this change) reads as every section picked; `Run.Normalize(run, plan)` fills them on open. `ct` stays 1 because the fields are additive and readers ignore them.

### D3. `deselected` is a verdict, kept out of `order`
Like `inapplicable`, a deselected step has no place in `order`, so next, back, "open" and the results screen skip it with no change. `Run.Counts` gains `deselected`. `Run.Select(run, ctx, id)` rebuilds `order` in plan order and keeps `current` by step id. `history` holds ids only, so Undo stays valid.

### D4. Trigger and rerun are state changes only
`Run.Trigger(run, ctx, name)` resolves a category or step id, selects the category if needed, and sets `current`. `Run.Rerun(run, ctx, category)` sets each step to `pending`, keeps attempts, drops the step ids from `history` and leaves the run open. Nothing sends input. Both return a reason line, so the slash command, the tracker click and the menu share one code path in `App`.

### D5. Category state is a pure function
`Run.CategoryState(run, id)` returns `state` (`red`, `yellow`, `green`, `blue`, `grey`, `off`) with counts `{pass, partial, fail, skip, unverified, pending, total}`. Order of tests: red if any fail; yellow if any partial or unverified; green if no open step and one pass; blue if any step is still open (untested, or in progress when others have results); else grey. `Run.OverallState` applies the same rule across picked steps. The card, Home list, `/ct categories`, the report tool and tests all call it. The tool has a Python copy, checked by a shared fixture.

### D6. Evidence: one operator table, parsed values, a fact kind
`Evidence.Ops` extends the `state` table (`ge`, `le`, `between`, `approx`, `matches`, `type`, `in`, `missing`) and the new `fact` kind uses it. `Evidence.ParseValue` turns fact text into boolean, number or string. `matches` uses the same 200 character pattern cap and `pcall` as log patterns. `Plan.OPS` is the one list the validator, the schema test and the tool compare.
Result mapping, chosen so a contradiction fails and a wait is unverified: no fact → unverified; facts that break the operator → fail; `which` picks last, any or all.
*Alternative:* match facts with the existing text `equals`. Rejected: no ranges, types or tolerance, and `1` versus `1.0` differ.

### D7. Counts and quiet sources
`count` runs over the new lines that match, for `log` and `fact`. Too many → fail; too few → unverified (it may still arrive); a count that allows zero follows the absence rules (readable log, known boundary). `quiet = true` on a source lets zero new lines count as a pass for those cases. Existing `absent` on a non-quiet source keeps today's "no new lines → unverified" result, so no existing plan changes meaning.

### D8. CheckThat records Lua errors itself, and reads BugGrabber when it holds the slot
`Adapter.HookErrors(make)` (the only place that calls `geterrorhandler` and `seterrorhandler`, in `pcall`) chains a handler and **reads the handler back**, because BugGrabber replaces the global `seterrorhandler` with a no-op after taking the slot (verified in its source, docs/contracts.md). `Model/Errors.lua` (plain Lua, shaped like `Facts.lua`) keeps a bounded list at `CheckThatDB.global.errors` while a run is open: 100 lines, 200 characters each, 30 a second. Our handler always calls the earlier handler and never raises. It is set again at run start and on trigger when the slot is no longer ours.
When the set is blocked, `Errors.Sample()` reads `BugGrabberDB.errors` and records one line for each rise of a counter (BugGrabber folds a repeated error into one entry and counts it, so position alone would miss a repeat). It takes a baseline at run start (`Rebase`) and samples before a step opens, before a result is judged, in the automatic settle and on the card's check refresh. The two paths never both run: sampling stops when our handler is current.
A result judged while nothing records (no handler of ours, no BugGrabber list) adds one line saying so, so a no-error check fails instead of passing on silence. Our handler contains a failure of the earlier handler and never raises in the game's handler. Rerun drops a retry the card had opened, so a fresh attempt takes new log positions. Facts and errors follow the character's open run, not the run the card shows.
*Alternative:* only read BugGrabber's list. Rejected: it needs another addon, and a client without it would give no errors at all.
*Risk:* the error handler is shared by every addon. Mitigation: chain, `pcall` our own work, report `handler: current|replaced|blocked|off`. A second addon that takes the slot without BugGrabber's no-op shows as `replaced` and is hooked again at the next run start or trigger.

### D9. The tracker is plain textures with a caption, and read-only
Each category is a pair of textures (back and fill) in the 3 unit slot of the existing progress bar, in a row of two to eight. The existing bar is textures too, so no new control type is added. A caption under the bar says the overall result in words ("1 failed · 3 of 8 passed"). A segment is not one color: it shows its steps side by side, green passed, yellow partial or unverified, red failed, over a track that is dim blue while steps are untested. (A category with one failure among six passes was drawn all red and read as a total failure.) The window has no overall count in its header, as its rows carry the counts. Segments carry a tooltip with the category in words and counts and **take no click**: a 3 unit target beside a draggable header is too easy to miss or to hit by mistake. One category keeps the plain bar. More than eight show one bar colored by the overall state. The count includes unpicked categories, so adding one never moves the others. The collapsed card keeps the caption. Segments follow the card's text opacity and draw nothing at zero.
Colors: blue `0.4,0.7,1` (untested, the card's progress blue), yellow `1,0.82,0` (partial or unverified, as elsewhere), green `0.1,0.8,0.1`, red `0.9,0.2,0.2`, grey `0.5,0.5,0.5` (only skips). Blue has two words: untested, in progress. Grey: all skipped, no steps.
*Alternative:* `StatusBar` segments. Rejected for now: the card's bar is textures, and the Blizzard source for `StatusBar` use on Era could not be read (see docs/contracts.md).
*Review:* Codex reviewed this design twice, the second time for the Categories window and the color rule. Adopted from the second review: captions that name the count ("1 failed", "1 partial", "2 unverified"), compact row details, page buttons, Esc, an arrow and hint on rows, a dim state-colored track for picked segments. Kept as is: the window opens only on request, and segments take no click.
*First review.* Adopted: read-only segments, caption with the overall result, distinct grey words, confirm on rerun, ids in `/ct categories`, refusing an ambiguous name, checkboxes in plan order, separate "Add to run" and "Go to first open step". Codex advised against yellow for in-progress. The request later made blue mean untested, so in-progress is blue and yellow is only partial or unverified.

### D10. Choosing categories uses stock controls
The Home page uses one AceConfig `toggle` per category (up to 24), in plan order, hidden when the plan has one category. AceConfig sorts `multiselect` keys, which would reorder them. The card start screen uses one `CheckButton` (`UICheckButtonTemplate`) per category, up to 8, with Start run off and a line when none is checked; a plan with more points to Home. The **Categories window** (`UI/Tracker.lua`, opened by the card's Categories control and `/ct tracker`) is a second movable frame with one row per category, 14 rows, then the mouse wheel or page buttons; Esc closes it. Each row has an arrow and the hint "Click for actions". It uses the card's opacity settings and remembers its place and whether it was open. A row click opens the Adapter's `ContextMenu` with the items for that category: Add to run (not picked), Go to first open step (steps open) and Rerun category (steps have results). Without a menu API the main item runs at once. Rerun asks first, from the menu and from `/ct rerun`. `/ct run <category>` adds and jumps in one action, and its help says so.

### D11. Parameterized steps are compile-only
`tools/ct.py` expands `cases` before encoding. The addon rejects `cases` as an unknown field, so a plan can never carry unexpanded data. Placeholders are `{{name}}`, replaced in all string values of the step, so a Lua pattern with braces is unaffected.

### D12. Existing plans and tests
- `plans/selftest.yaml` gains declared categories (`card`, `evidence`, `facts`, `errors`) and steps for typed facts, a count and the error source, using `/ct fact` variants. The other plans keep sections as categories. No edit.
- Tests that change: `test_plan` (validation), `test_run` (New with picks, Counts, history), `test_evidence`, `test_facts` (typed values), `test_app` (Start with picks, Normalize), `test_card` and `harness` (StatusBar, GameTooltip, error handler), `test_slash`, `test_options`, `test_selftest`, `test_smoke` (new file in both TOC files), `test_readme`, `test_locale`, and the Python tests (`tools/test_*.py`). Every assertion about the card's progress bar moves to the tracker.
- New: `tests/test_errors.lua`, `tests/test_categories.lua`.

### D12b. Self-test commands
`/ct selftest facts` reports typed facts and `/ct selftest error` passes a message to the error handler, so the self-test checks typed facts, a count and the error list with Run button clicks. `/ct fact` is unchanged.

### D13. Version
Addon code changes and the change is a new capability: bump 0.9.1 → 0.10.0 at archive, with the CHANGELOG section.

## Risks / Trade-offs

- [Error handler conflict with other addons] → Chain and re-check; record on the debug report; never replace the earlier handler's result.
- [A tracker row crowds a 380 wide card] → Cap at 8 segments; the caption and Home list carry the rest.
- [Color alone] → Caption, tooltip and Home list use words and counts.
- [Old saved runs] → `Run.Normalize` on open, tested with a fixture copied from a real run, anonymized.
- [Larger assertion set means more plan mistakes] → Validation names step, field and operator; `docs/authoring-plans.md` gets one example per type; `ct-test-plan` and `ct-verify` skills learn the new kinds.
- [Fact text parsing guesses types] → The rule is fixed (true, false, number, else text) and the `type` operator lets a plan state its expectation.

## Migration Plan

No data migration. Runs and plans without the new fields behave as before. Rollback: a 0.9.x addon opening a run saved by 0.10 ignores the extra fields; its plan validation rejects a new plan, which says what to update.
