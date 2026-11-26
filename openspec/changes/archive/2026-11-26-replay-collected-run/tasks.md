# Tasks

## 1. Replay against a collected run (#223)

- [x] 1.1 `run_sv_files(dest, run_id)` in `tools/ct.py`: newest stored revision, the CheckThat copy that holds it, client and account prefix, account-wide and own-character addon copies, per file the newest copy no later than the CheckThat copy (one minute of slack), warning when every copy is later. Verify: tests with a fake evidence folder for two characters sharing a global, three collects, an unchanged account-wide file, a realm of `?`, Era and Forever folder names, a run no copy holds (exit 2), and an unknown run id (exit 2); break the character filter and see the test fail
- [x] 1.2 `replay` takes `--run` and `--dest`; exactly one of `--sv` and `--run`; prints the files used; `--sv` unchanged. Verify: CLI tests for both options, neither, and both; an existing `--sv` test still passes

## 2. Report version from the TOC (#226)

- [x] 2.1 `report` takes `--addon-src`; without `--expect-version`, the TOC version from `--addon-src` or the `--plan` file's `offline.toc`; prints the source; explicit wins. Verify: tests for the default, the explicit override, the plan fallback and no TOC (old output); break the default and see the test fail

## 3. Skills, docs and check

- [x] 3.1 `skills/ct-test-plan/SKILL.md` "Revise after a run": replay the revised plan with `--run` before another in-game run, and what a pass proves; `report --addon-src`. `skills/ct-verify/SKILL.md`: `report --addon-src`. `docs/authoring-plans.md` (Check a plan against saved variables) and `docs/skills.md`. Verify: skill text test and the flag lint in `make test`
- [x] 3.2 `make test` and `make check` pass; no file under `CheckThat/` changes

## Workflow follow-up

- Archive with `/opsx:archive` (no version bump: no addon code). Commit with the synced specs and archive, naming #223 and #226.
