# Tasks

- [x] 1.1 `Evidence.Check` returns the detail for log, sequence, fact and state checks; fill the missing reasons. Verify: `tests/test_hits.lua`; break overflow, sequence and fact hit rules and see it fail.
- [x] 1.2 `Run.Verdict` keeps it for outcomes that are not a pass; the budget counts it and marks trimmed. Verify: `tests/test_hits.lua`.
- [x] 2.1 `ct.py`: validate, report lines and marks, json and junit with `--lines`. Verify: `tools/test_ct.py`.
- [x] 2.2 `schema/run-results.schema.json`, tested against a run the addon wrote.
- [x] 2.3 The viewer: a panel for each failed check and marked excerpt lines. Verify: `tools/test_ct_tui.py`.
- [x] 3.1 Docs, skill, manual check, changelog, version 0.14.0.
