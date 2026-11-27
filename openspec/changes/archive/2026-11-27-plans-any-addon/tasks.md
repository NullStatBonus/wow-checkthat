# Tasks

- [x] 1.1 `Plan.lua`:
  - addon name rule, `commands` validation, `Plan.DENY`, `Plan.CommandProblem` and `Plan.Allow`;
  - `Plan.REV` 2;
  - tests in `tests/test_plan.lua`.
- [x] 1.2 `App.lua`:
  - `DeclareCommands`, `CommandsCheck` (kept per plan), `AllowedCommands` and `CommandsNote`;
  - `MacroText` uses the owned list;
  - a log line at start;
  - tests in `tests/test_app.lua`.
- [x] 1.3 `Adapter.SlashOwner`, with a test in `tests/test_adapter.lua`. `CheckThat.Commands` and `API_VERSION` 4, with tests in `test_entry_api`, `test_facts`, `test_smoke`, `test_clients` and `test_runcallback`.
- [x] 1.4 `/ct start` for any imported plan (`tests/test_slash.lua`), the start-screen note (`Card.lua`) and the `Plan commands` report line.
- [x] 1.5 `ct.py`:
  - `command_problem`, `plan_commands` and `macro_allowed` with the plan's prefixes;
  - the `PLAN_NEEDS` rule for `commands`;
  - `from-md` and `coverage` for any addon;
  - tests, and parity of `DENY` and `COMMANDS_MAX` with `Plan.lua`.
- [x] 1.6 Schema, specs, docs and skill. `plans/selftest.yaml` checks API version 4.
- [x] 1.7 Break each rule once; each test failed. The `ct.py` deny test was tightened after it passed for the wrong reason.
