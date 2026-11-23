# Tasks

## 1. Rule text

- [x] 1.1 Reword the Adapter convention in `AGENTS.md` with the `UI/` and `Debug/` carve-out. Verify the text matches the spec delta and keeps the "unknown is nil" sentence.

## 2. Layering test

- [x] 2.1 Extend `tests/test_layers.lua` with a scan of `Model/`, `Options/` and `Core/` (not `Adapter.lua`) for bare game globals. Verify `luajit tests/test_layers.lua` passes.
- [x] 2.2 Temporarily add a bare `CreateFrame` call to a Model file. Verify the test fails and names the file, then remove it and verify the test passes.
- [x] 2.3 Run `make test` and `make check`. Verify both pass and `git diff --stat` shows nothing under `CheckThat/`.

## Workflow follow-up

- Archive without a version bump (no addon code changed). Close issue #4 with the commit.
