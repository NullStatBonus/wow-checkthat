# Tasks

## 1. Singular text

- [x] 1.1 Use two sentences for the rerun question and the reopen message. Verify: `luajit tests/test_card.lua`.

## 2. Rerun failed

- [x] 2.1 `Run.Rerun`, `App.RerunCount`, `/ct rerun failed`, the row menu item. Verify: `luajit tests/test_categories.lua`, `test_app`, `test_slash`, `test_tracker`.
- [x] 2.2 Reject the reserved id in `Plan.lua`, `tools/ct.py` and the schema. Verify: `luajit tests/test_plan.lua`, `tools/test_ct.py`.
- [x] 2.3 Break the failed predicate, see the test fail, restore.

## 3. Docs and release

- [x] 3.1 README, features, listing, authoring, test plan check 7, changelog, version 0.11.0. Verify: `make test` and `make check`.
