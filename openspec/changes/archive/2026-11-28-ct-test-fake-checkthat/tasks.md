# Tasks

## 1. Runner

- [x] 1.1 `opts.checkThat` (`early`, `late`, `missing`): build `_G.CheckThat` from CheckThat's `Facts`, `Entries`, `RunEvents` per load, with `Commands`; offline blocks keep today's fake
- [x] 1.2 `late` and `missing` load orders
- [x] 1.3 `ctx.entry`, `ctx.reports`, `ctx.run`; the open run survives a reload
- [x] 1.4 Lua tests in `tests/test_entries.lua`; break each behavior and see the test fail

## 2. ct test

- [x] 2.1 `tools/addon_test.lua` passes `checkThat` (option checked) to the runner
- [x] 2.2 Fixture `TestedAddon` integration and tests in `tools/test_ct.py`; break each behavior and see the test fail

## 3. Docs

- [x] 3.1 `docs/addon-tests.md` (option, a worked integration test), `ctx` table in `docs/authoring-plans.md`
