# Tasks

## 1. Addon (#79)

- [x] 1.1 Excerpt budget per run (`Run.TrimExcerpts`). Verify: `tests/test_run.lua`; test fails without the call.
- [x] 1.2 `App.Begin` asks for a stack only for a new attempt. Verify: `tests/test_app.lua`; test fails when always called.

## 2. Tools (#78, #79, #71)

- [x] 2.1 `classify`, earlier attempts, stacks, `result:` line in the report.
- [x] 2.2 `--format json|junit`, `--strict`, `--stacks`, `--out`.
- [x] 2.3 `status` and `problems.log`; error lines and stacks kept by `collect`; conflict check ignores snapshots.
- [x] 2.4 Break each behavior once, see `tools/test_ct.py` fail, restore.

## 3. Docs and release

- [x] 3.1 README, `docs/harvesting.md`, `docs/features.md`, `docs/skills.md`, `skills/ct-verify/SKILL.md`. agy reviews the text.
- [x] 3.2 Version 0.13.1 in both TOC files and `CHANGELOG.md`.
- [x] 3.3 #26 and #61 stay open (see design Non-Goals).
