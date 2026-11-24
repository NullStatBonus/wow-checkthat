# Tasks

## 1. Remove from run (#60)

- [x] 1.1 `Run.Deselect` with the clean-category rule, last-category rule and view handling. Verify: `tests/test_run.lua` (break the rule and see it fail).
- [x] 1.2 `App.Deselect` with log line `deselect <id>` and reason texts. Verify: `tests/test_app.lua`.
- [x] 1.3 "Remove from run" in `Card.CategoryItems`. Verify: `tests/test_card.lua`.

## 2. Category picker (#77)

- [x] 2.1 `UI/Picker.lua` (14 rows, wheel, page buttons, checkboxes) in both TOC files. Verify: `tests/test_card.lua` and `make check`.
- [x] 2.2 Choose categories button on the start screen above 8; inline boxes stay up to 8. Verify: `tests/test_card.lua`.
- [x] 2.3 Home pages the 24 toggles with an offset and page buttons. Verify: `tests/test_options.lua`.

## 3. Key bindings (#7)

- [x] 3.1 `Bindings.xml`, binding names in `Locales/enUS.lua`, global functions that call the verdict path. Verify: `tests/test_card.lua` (hidden card, no run, bound press) and `make check`.

## 4. Report follow-ups (#81)

- [x] 4.1 Stacks per attempt in `tools/ct.py`, junit `system-out`. Verify: `tools/test_ct.py`.
- [x] 4.2 "Awaiting retry" and evidence `none` for a reopened step. Verify: `tools/test_ct.py`.
- [x] 4.3 Shared new-attempt helper arms the stack in `App.Verdict`. Verify: `tests/test_app.lua` or `test_errors`.

## 5. Docs, review and checks

- [x] 5.1 README, `docs/features.md`, `docs/listing.md`, `docs/harvesting.md`, `docs/test-plan.md` (short manual checks for the picker and a bound key).
- [x] 5.2 Codex UX review of the picker, the menu item and the bindings, then fix findings.
- [x] 5.3 Codex adversarial review of the diff (stale state, removal races, empty and huge category lists), then fix findings.
- [x] 5.4 `make test` and `make check`.

## Workflow follow-up

- Addon code changes: bump the version in both TOC files (minor), add the changelog section, then archive before commit.
- Close #81, #60, #77, #7 in the PR.
