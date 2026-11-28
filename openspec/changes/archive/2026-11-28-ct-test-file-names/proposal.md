# Proposal

## Why

`ct test` runs only `tests/test_*.lua`. Many addon repos name their tests `*_test.lua`, and keep them with the files of their own test runner. Run with `--tests ../tests` in such a repo, `ct test` finds nothing, or would fail every file of the other runner.

## What Changes

- `ct test` runs `test_*.lua` and `*_test.lua` in the tests folder (`<folder>/tests` or `--tests DIR`).
- A matching file whose text never names `ct.test` belongs to another runner. It is skipped and listed (`skipped N file(s) that do not call ct.test: ...`). A file that names `ct.test` and registers no test still fails.
- When every matching file is skipped, the command exits 2 and says the files are for another runner.
- Docs: `docs/addon-tests.md`.

## Capabilities

### New Capabilities

### Modified Capabilities
- `offline-entry-runner`: which files `ct test` runs.

## Impact

`tools/ct.py`, its tests and the docs. `ct test` is not released yet (PR #283), so no released behavior changes. No file under `CheckThat/` changes.
