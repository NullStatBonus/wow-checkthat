# Tasks

- [x] 1.1 Fixture addon with a file-scope capture, a call-time lookup, an event handler and a registered entry. Verify: `tests/test_entries.lua`.
- [x] 1.2 `tools/entry_runner.lua`: load TOC under the fake client with mocks, call entries, check returns, throws and call counts, fire events, restore mocks. Verify: break each behavior and see its test fail.
- [x] 1.3 Local-capture test: a mock set before load reaches the capture; one set after load does not.
- [x] 1.4 Measurements and result in `docs/contracts.md` (captures, harness additions, taint unmeasured) with a build, defer or drop call per part.
- [x] 1.5 File follow-up issues for the deferred parts and name them in design Non-Goals.

## Workflow follow-up

- No version bump, changelog entry or tag: no file under `CheckThat/` changes.
