## 1. Model

- [x] 1.1 Add `Run.End(run, now)` and the ended guard in `Run.Verdict`, `Run.Undo`, `Run.UndoLast`, `Run.AutoSettle` in `CheckThat/Model/Run.lua`. Test in `tests/test_run.lua`.
- [x] 1.2 Add `App.End()` with the same-run re-check, the debug log line and the secure-button reset in `CheckThat/Model/App.lua`. Test in `tests/test_app.lua`.
- [x] 1.3 Skip ended runs in reload resume. Keep `endedAt` in `Run.Export`. Test that an older save without `endedAt` still loads.

## 2. Command

- [x] 2.1 Add `/ct end` and its help text in `CheckThat/Core/Slash.lua`, sharing one `confirmEnd` dep with the card. Cover no run, already ended and confirmed. Test in `tests/test_slash.lua`.
- [x] 2.2 Add the menu helper in `CheckThat/Core/Adapter.lua`: `MenuUtil`, then `UIDropDownMenu`, then nil. Guard and `pcall` each call. Test the three paths with the fake client.

## 3. Card

- [x] 3.1 Turn the header label into a "Run" menu with End run... in `CheckThat/UI/Card.lua`. Use the fallback button when the adapter returns nil. Cover the collapsed strip.
- [x] 3.2 Show "Run ended" with Export results and Main window. Hide Resume, Undo and the verdict row for an ended run.
- [x] 3.3 Add new `L["..."]` sentences to the locale files. `tests/test_locale.lua` must pass.

## 4. Report and docs

- [x] 4.1 Print the ended line in `/ct status run` and the `/ct log` report.
- [x] 4.2 Update `README.md` (command list, Good to know), `docs/listing.md` and `docs/test-plan.md` (one short check: menu, confirm, "Run ended", Export). `tests/test_readme.lua` must pass.
- [x] 4.3 Record the menu API each client provides in `docs/contracts.md` if a probe measures it. (No probe measured it. Nothing to record. The fallback covers a missing API.)
- [x] 4.4 For each new test, break the behavior, see it fail, restore it. Then run `make test` and `make check`.
