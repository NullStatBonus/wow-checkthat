# Tasks

- [x] 1.1 `Model/Blocked.lua` with `Bind`, `Record`, `IsEventMessage` and `Count`, in both TOCs and the harness. Tests in `tests/test_blocked.lua`:
  - the line format, and macro events;
  - recording only while a run is open, and only for listed events;
  - cleaning;
  - the rate limit and the cap;
  - BugGrabber's copy staying out of the errors.
- [x] 1.2 `Errors.Sample` filter, `App.Init` binding, the `Core/Addon.lua` listener, and the report line. Smoke test: the real addon records an event fired through AceEvent, and the report counts it.
- [x] 1.3 Docs and spec delta.
- [x] 1.4 Break each behavior once; each test failed.
