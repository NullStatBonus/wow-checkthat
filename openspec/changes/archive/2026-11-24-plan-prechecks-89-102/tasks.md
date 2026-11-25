# Tasks

## 1. Lint rules (#102)

- [x] 1.1 Add the own-result-line error to `validate` in `tools/ct.py`, with a test in `tools/test_ct.py`. Remove the rule, see the test fail, restore it.
- [x] 1.2 Add the first-step version-check warning and its test the same way.

## 2. Replay against a fixture (#89)

- [x] 2.1 Write `tools/replay_sv.lua`: load plan and fixture, judge log and fact checks with `Evidence.Check`, mark window and missing-probe checks not judged.
- [x] 2.2 Add `ct.py replay <plan> --sv <dir>` with JUnit output, a non-zero exit on a contradicted required check, and the fixture age and digest warning.
- [x] 2.3 Add an anonymized fixture and tests: typo fails, corrected plan passes, forbidden line fails, window check is not judged, stale digest warns. Break each behavior first and see the test fail.

## 3. Skill and docs

- [x] 3.1 Update `skills/ct-test-plan/SKILL.md` and `reference.md`: auto or manual question, manual `expect` ends with the press, auto `timeout` default 120, new-UI checks say what the tester should see, run `tests/replay_plan.lua` after `compile`, stale-bundle warning.
- [x] 3.2 Update `docs/authoring-plans.md`, `docs/harvesting.md`, `docs/skills.md` and the README command list; keep `tests/test_readme.lua` green.
- [x] 3.3 Add manual checks to `docs/test-plan.md` only where a player action is involved; none expected.

## 4. Close out

- [x] 4.1 Run `make test` and `make check`.
- [x] 4.2 Open an issue for the other-addon version fact and name it in `design.md` Non-Goals.
- [x] 4.3 Archive without a version bump: no file under `CheckThat/` changes.
