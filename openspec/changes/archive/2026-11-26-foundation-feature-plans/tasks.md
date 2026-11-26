# Tasks

## 1. Plan format and validate

- [x] 1.1 Schema: optional top-level `purpose` (enum `foundation`, `feature`), described as tools only; `merge_sections` in `tools/ct.py` drops it. Verify: a test shows `purpose: release` fails validate and the compiled string is byte-identical with and without `purpose`
- [x] 1.2 `wording_warnings(plan)` in `tools/ct.py`, printed by `print_warnings` only when the plan has `purpose`: slash command in action text (not `copy-slash`) or in `expect`, log words in `expect` (not "log in", "log out", "log on"). Verify: tests for colored and plain commands, copy-slash, "logs", "logged", "log in", and no warning without `purpose`; break the purpose gate and the log-in exclusion and see each test fail
- [x] 1.3 Foundation size warning above 12 steps after `cases` expand, in `size_warnings` or beside it. Verify: tests for 12 and 13 steps, a feature plan of 13 (no warning), cases counted; `validate` prints it and exits zero
- [x] 1.4 `openspec/specs/test-plan-format` delta matches the code (already drafted); `schema/test-plan.schema.json` and the format spec agree. Verify: `make test`

## 2. Skill and docs

- [x] 2.1 `skills/ct-test-plan/SKILL.md`: Interview item 6 asks "foundation or feature?" first, then the pillar interview (foundation) or the case interview (feature); set `purpose`; draft rules for one character, one step per pillar, sections by pillar, no restore-only step, the preamble's assumptions and what leaves the gate; wording rules; "Plan sets by area" is for feature scope, not the release gate; Review adds the single-character and pillar checks; Validate names the new warnings. Verify: `make test` (skill text tests) and a read-through against the spec delta
- [x] 2.2 `skills/ct-test-plan/reference.md` checklist: foundation, feature and wording items. `example.yaml`: `purpose: feature`, player-language action text, commands only in `commands`. Verify: a test that the example plan and the role examples validate with no wording warning
- [x] 2.3 `docs/authoring-plans.md`: "Foundation and feature plans" section (pillars, one character, size, wording), "Keep a plan short" and "Plan sets" updated; `docs/skills.md` one line. Verify: `make test` (docs name only integrated addons)
- [x] 2.4 `docs/test-plan.md` §6: one manual check that the skill asks "foundation or feature?" and drafts a foundation plan for one character. Verify: section numbers stay unique and in order

## 3. Check

- [x] 3.1 `make test` and `make check` pass; `git diff --stat` shows no file under `CheckThat/`; validate output of every plan under `plans/` is unchanged

## Workflow follow-up

- Archive with `/opsx:archive` (no version bump: no addon code). Commit the code, synced specs and archive together, naming #219.
