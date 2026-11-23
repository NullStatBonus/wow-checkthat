# Tasks

## 1. Window

- [x] 1.1 Add a failing test: `Export.Show` opens an AceGUI Frame whose box holds the text, and the Frame is above the card's Run button. Verify: the test fails before the change.
- [x] 1.2 Rewrite `Export.Show` to use AceGUI Frame and MultiLineEditBox, with the fallback to the old window. Verify: `luajit tests/run.lua` passes.
- [x] 1.3 Add the status line text to the locale file as one literal key. Verify: `tests/test_locale.lua` passes.

## 2. Docs and release

- [x] 2.1 Update `docs/test-plan.md` (the report and results checks), README if it describes the window, and `docs/listing.md` if needed. Verify: `make test`.
- [x] 2.2 Version 0.8.3 in both TOC files and a `CHANGELOG.md` section. Verify: `make check`.
