# Tasks

## 1. Command

- [x] 1.1 Add `/ct version` to `Slash.lua`. Verify in `tests/test_slash.lua`: the printed text, the number for 0.17.3 and 1.2.3, no fact for an unknown version, no fact with no run, an argument refused.
- [x] 1.2 Document it in the README and `docs/features.md`. Verify `tests/test_readme.lua`.

## 2. Plans

- [x] 2.1 Start `plans/checkthat-0.17.yaml` with the version step. Verify `ct.py validate` and `compile`.
- [x] 2.2 Add the first-step rule to `skills/ct-test-plan/SKILL.md` and `reference.md`.

## 3. Release

- [x] 3.1 `make test` and `make check` pass.
