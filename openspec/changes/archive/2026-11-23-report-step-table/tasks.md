# Tasks

## 1. Report table (#10)

- [x] 1.1 Add the all-steps table to `report_text` with evidence states met, bad, missing, none. Verify: `tools/test_ct.py` has cases for pass with evidence, pass without, fail, skip and inapplicable.
- [x] 1.2 Break the table (drop passing rows), see the test fail, restore.
- [x] 1.3 Document the new report in the README. Verify: `make test`.

## Workflow follow-up

- No version bump, changelog entry or tag: no file under `CheckThat/` changes.
- Close #10 when merged.
