## 1. Plan format

- [x] 1.1 Schema: `action.text` and `expect` as string or list of 2-6 strings; step `async`; requirement `class`, `profession`, `unmet`
- [x] 1.2 `Plan.lua` import checks for the same; list items checked as text
- [x] 1.3 `ct validate`: one-item list, async rules, class tokens; every reader of `action.text` and `expect` handles a list
- [x] 1.4 Python and Lua tests for each rule; old plans keep their digest (GoldenPlans)

## 2. Run model

- [x] 2.1 `Run.Tick` and `attempt.ticks`; raise `Run.FORMAT_REV`
- [x] 2.2 Adapter class token and professions; `Run.Blocked` returns the unmet mode; inapplicable at `Run.Begin`
- [x] 2.3 `Run.JudgeAtStart` from `App.Start` and `Run.Rerun`; `at = "start"`
- [x] 2.4 Lua tests: ticks survive reload and stay off the verdict; Hunter gets inapplicable; unknown class stays applicable; async pass at start, async miss settles on its turn, no attempt opened or entry called

## 3. Card

- [x] 3.1 Title font object with fallback
- [x] 3.2 Do checkbox rows (pool, reset, fallback text rows), Expect lines
- [x] 3.3 "CheckThat checks" heading; remove both banners and their strings
- [x] 3.4 Setup fold with first-visit open; preamble and section intro inside; Blocked stays outside
- [x] 3.5 Reloaded in the hint line; "Add note" control
- [x] 3.6 Hold and fade after an automatic result; press ends it; result press dropped with a chat line; no hold when hidden or collapsed
- [x] 3.7 Lua tests through the fake client for each card change and the fade (stub the timer); `test_locale` passes

## 4. Tools and replay

- [x] 4.1 `ct report` and `ct show`: unticked actions, "passed at run start", inapplicable reason
- [x] 4.2 `replay_plan.lua` and `replay-flow`: async at start, inapplicable by hooks
- [x] 4.3 Python tests

## 5. Docs and skill

- [x] 5.1 `DESIGN.md` §3, `README.md`, `docs/features.md`, `docs/authoring-plans.md`, `docs/results-format.md`, `docs/listing.md`
- [x] 5.2 `docs/test-plan.md`: manual checks for the checklist, the fade, inapplicable and async
- [x] 5.3 Skill: list actions, `async` for startup checks, `unmet: inapplicable` in feature plans; examples
- [x] 5.4 `CHANGELOG.md` 0.21.0 lines
- [x] 5.5 `make test`, `make check`, `make mutate` survivors read
