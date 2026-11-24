# Tasks

## 1. Command

- [x] 1.1 Add `/ct fact` to `CheckThat/Core/Slash.lua` (no arguments, same gate and limits, one result line) and name it in the diagnostics help line.
- [x] 1.2 Test it in `tests/test_slash.lua`: run open, no run, an argument, and the help line. Break the call and the argument check in turn and confirm the tests fail.

## 2. Self-test

- [x] 2.1 Make `self.facts` in `plans/selftest.yaml` a Run button step that runs `/ct fact`. Update `tests/test_selftest.lua` to drive the command, and mutation-check it.

## 3. Docs and release

- [x] 3.1 README command table, `docs/features.md`, `docs/test-plan.md` checks 10 and 11 (click Run, then type `/ct fact` with no run).
- [x] 3.2 Run `make build`, `make test` and `make check`.
- [x] 3.3 Archive, bump both TOC files to 0.9.1 with a `## 0.9.1` CHANGELOG section, commit and push to PR 57.
