# Tasks

## 1. Flow replay for any addon

- [x] 1.1 `tests/replay.lua` writes the plan's own log sources, derives lines from patterns and sequences, marks reload steps, warns "evidence assumed"
- [x] 1.2 Tests in `tests/test_replay.lua`; break the write once and see the test fail
- [x] 1.3 `ct.py replay-flow`, `ct.py lines`, `default_addons`

## 2. Bundle and launcher

- [x] 2.1 Makefile `BUNDLE`, `BUNDLE_DIR`, `BIN_DIR`, `tools/ct`
- [x] 2.2 Bundle test runs replay-flow and offline from another folder; break it by dropping the harness

## 3. Review gate and run checks

- [x] 3.1 `validate` card-move warning, `diff` renamed, `report` version and digest warnings, each with a test that fails when broken
- [x] 3.2 `ct-test-plan` and `ct-verify` text; docs

## 4. Review fixes and check

- [x] 4.0 Fix every finding of the Codex and Opus reviews, each with a test

- [x] 4.1 `make test` and `make check` pass; `git diff --stat` shows no file under `CheckThat/`
