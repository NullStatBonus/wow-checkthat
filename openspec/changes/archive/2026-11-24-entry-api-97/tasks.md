# Tasks

## 1. Addon
- [x] 1.1 `Model/Entries.lua`: register, outcome, run; add to both TOCs after Facts.
- [x] 1.2 `Facts.API`: `Entry`, `API_VERSION` 2. Bind in `App.Init`; `Adapter.Env` reads `InCombatLockdown`.
- [x] 1.3 `App.Begin` calls the step's entry for a fresh attempt.
- [x] 1.4 `Plan.lua` validates `call`; schema and `ct.py` mirror it.

## 2. Tests (each broken first)
- [x] 2.1 `tests/test_entry_api.lua`: register, call and pass, wrong value, unregistered, throw, combat, run open, reload, validation.
- [x] 2.2 `tools/test_ct.py` `EntryCall`.

## 3. Docs and release
- [x] 3.1 features, contracts, results-format, authoring-plans, README, debug-logging.
- [x] 3.2 Version 0.18.0 in both TOCs and a CHANGELOG section.
- [x] 3.3 `make test`, `make check`, archive.
