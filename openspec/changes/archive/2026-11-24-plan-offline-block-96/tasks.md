# Tasks

## 1. Runner
- [x] 1.1 Add the closed mock allow list to `tools/entry_runner.lua`; an unlisted mock fails before load and replaces nothing. Test in `tests/test_entries.lua`; remove the check, see it fail, restore.

## 2. Plan format
- [x] 2.1 Add `offline` to `schema/test-plan.schema.json`. Test: valid block passes, unknown step field fails.
- [x] 2.2 Drop `offline` in `merge_sections`. Test: compiled string equals the one without the block.

## 3. Command
- [x] 3.1 Add `ct.py offline <plan> [-o]`: resolve `toc`, run the runner, print JUnit, exit 0/1/2. Add a fixture plan against `tests/fixtures/mockaddon`. Tests: wrong return fails, matching passes, no block exits 2, unlisted mock fails. Break each first.
- [x] 3.2 The skill does not run the runner, so `entry_runner.lua` stays out of `BUNDLE`.

## 4. Docs
- [x] 4.1 `docs/authoring-plans.md` section "Check addon code offline", the README Develop line, `docs/skills.md` if the skill changes. Keep `tests/test_readme.lua` green.
- [x] 4.2 Open an issue for per-category setup with restore; name it in `design.md` Non-Goals.

## 5. Close out
- [x] 5.1 `make test` and `make check`.
- [x] 5.2 Archive without a version bump: no file under `CheckThat/` changes.
