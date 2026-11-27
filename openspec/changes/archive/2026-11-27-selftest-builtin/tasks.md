# Tasks

- [x] 1.1 `Model/BuiltIn.lua` from `make builtin`, in both TOCs and the harness. `tools/test_ct.py` fails when it differs from the compiled `plans/selftest.yaml`.
- [x] 1.2 `App.ImportChoices` and `App.BuiltInString`. Tests in `tests/test_app.lua`: the self-test first, recent plans after it, one entry after import, the stored copy reused, and the recent list alone when nothing is built in.
- [x] 1.3 The import window title, hint and "Choose a plan" label, and the empty card text. Smoke test: choosing the self-test imports it, opens the card with Start run, and leaves the box empty.
- [x] 1.4 Docs (README, `features.md`, `listing.md`, `publishing.md`, `test-plan.md`) and spec delta.
- [x] 1.5 Break each behavior once; each test failed.
