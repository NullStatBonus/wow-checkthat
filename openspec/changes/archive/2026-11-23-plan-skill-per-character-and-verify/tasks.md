# Tasks

## 1. Interview and draft (#33)

- [x] 1.1 Rewrite `skills/ct-test-plan/SKILL.md` section 1 to ask one question per turn, in dependency order, with the reason, the unlocked decision and a recommended answer. Skip questions the scope already answers and say what was assumed. Verify: a scripted interview on a fixture scope asks one question per turn and skips the answered ones.
- [x] 1.2 Rewrite sections 2 and 4 to draft and review one step at a time, with its evidence choice and client tags. A rejected new step stays out. A rejected edit to an accepted step leaves that step as it was. Keep accept all as an opt-in and keep the final coverage review, validation and compile. Verify: the scripted interview rejects a step and the plan omits it.
- [x] 1.3 State the simple-step default in `SKILL.md` section 2 and `reference.md`. Verify: the scripted interview with a two-action check gives two steps, and with a request for one compound step gives one step labelled compound.

## 2. One plan per character role (#52)

- [x] 2.1 Add the character question. Draft one plan per role, named `<name>.<role>.yaml`, with partner names in each preamble, a reviewer line, a compiled `.ct` for each and the import order. Support any number of roles. Verify: a dry run on #48 gives two plans; `$PY tools/ct.py validate` and `compile` pass for each, a script checks that each preamble names the other file and that the reviewer line names both files and the step IDs.
- [x] 2.2 Add the rule and an example to `reference.md` and `example.yaml`. Verify: `validate` passes on the example, and a script fails when a partner plan omits a partner reference in its preamble or reviewer line.

## 3. Verify skill (#34)

- [x] 3.1 Fix the bundle: add `tools/sv2json.lua` and `CheckThat/Model/Json.lua` to `BUNDLE`, and make `collect` report a decode failure on malformed input. Verify: tests in `tools/test_ct.py` install into a temp folder and run `collect` from a sibling directory on a synthetic SavedVariables file. They assert the expected run revision and step. A malformed file reports a decode failure. A valid empty database and the same revision collected twice report success with no new runs.
- [x] 3.2 Write `skills/ct-verify/SKILL.md`: locate tools as `ct-test-plan` does, collect or import results, bind runs to plans by digest, join partner runs by step ID, report verdict and evidence separately with citations, ask for run IDs when pairing is ambiguous, treat a pasted `/ct log` report as partial, never edit or run the game. Write evidence outside the bundle. Verify: anonymized fixtures with known verdicts give the expected report: a hand pass against a failed required assertion (contradicted), a hand pass with a missing line (unverified), a diagnostic failure (no contradiction), four characters whose plans reuse local step IDs, a missing partner run, a second eligible run for one role (the skill asks), a unique assignment (the skill does not ask), and an export with no plan (the skill says it cannot establish the plan).
- [x] 3.3 Extend `make install-skill` to install `ct-verify` with the same bundle. Verify: the install test from 3.1 covers both skills; `make test` passes.

## 4. Docs and close out

- [x] 4.1 Update `README.md` (it names a one-skill install; mention the `luajit` need) and `docs/test-plan.md` (interview, per-character plans, `ct-verify`, the scripted-interview and fixture checks). Keep the developer commands apart from the in-game `/ct` list. Verify: `make test` and `make check`.
- [ ] 4.2 Run the dry run on #48 and attach the two plans. Comment on #33, #34, #52 and #48. Check open issues before opening any new one, and record real deferrals in `design.md` Non-Goals.

## Workflow follow-up

- No version bump, changelog entry or tag: no file under `CheckThat/` changes.
- Fix the code path in #52: the skill lives in `skills/ct-test-plan/`.
