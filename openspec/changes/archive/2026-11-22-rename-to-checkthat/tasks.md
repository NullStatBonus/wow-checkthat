# Tasks

Each new behavior gets a test first. Break the behavior on purpose, check the test fails for the expected reason, restore it, check it passes.

## 1. Move the folder and rename

- [x] 1.1 `git mv TestThat CheckThat` and rename both TOC files. Apply the mechanical rename of Decision 1 to all tracked text files outside the archive, `CHANGELOG.md` history, the vendored libraries and `openspec/specs`. Verify with `rg -i testthat --glob '!openspec/changes/archive/**' --glob '!CHANGELOG.md' --glob '!CheckThat/Libs/**' --glob '!openspec/specs/**' --glob '!openspec/changes/rename-to-checkthat/**'` returning nothing, and with `make test` passing.
- [x] 1.2 Update `.pkgmeta`, `Makefile`, `tools/check-*.sh`, the TOC `IconTexture` path and `tools/sv2json.lua` for the new folder. Verify with `make check`.

## 2. Commands and plans

- [x] 2.1 Register `ct` and `checkthat` in `Slash.Register` and nothing else. Verify with a test that records the registered names.
- [x] 2.2 Give `Plan.SLASH.CheckThat`, `tools/wtt.py` and `plans/selftest.yaml` the commands `/ct` and `/checkthat`, and the schema the addon name `CheckThat`. Verify with new cases in `tests/test_plan.lua` and `tools/test_wtt.py`: both commands pass, `/wtt` and another addon's command fail.
- [x] 2.3 Make `tools/wtt.py` and `tools/Copy-WttEvidence.ps1` read `CheckThat.lua`; rename `by_testthat` and the report label. Verify with the existing `tools/test_wtt.py` collect and report tests.

## 3. Docs, specs and skill

- [x] 3.1 Update README (including the command table, with `/checkthat` as the long form), `docs/`, `DESIGN.md`, `AGENTS.md`, `CONTRIBUTING.md`, `THIRD_PARTY.md` and the skill. Add manual checks to `docs/test-plan.md` if a rename needs one. Verify with `tests/test_readme.lua` and a read of each file for leftover old names.
- [x] 3.2 Update the two spec Purpose lines that name the old name or `/wtt` (`slash-interface`, `test-plan-authoring`). Verify with `openspec validate --specs`.

## 4. Integration

- [x] 4.1 Run `make test` and `make check`; fix failures. Verify both exit 0.
- [ ] 4.2 In game: copy `CheckThat/` into `Interface/AddOns/`, log in, and check that the addon loads, `/ct` and `/checkthat` open the card, and the self-test plan runs. Read `/ct log`; do not ask the player to read a log line.

## Workflow follow-up

- At archive: sync the deltas, bump both TOC versions to 0.5.0, add the matching `CHANGELOG.md` section and name the version in the commit message.
- After the commit: rename the GitHub repository to `wow-checkthat` by hand; the CurseForge and Wago projects are renamed by hand too.
