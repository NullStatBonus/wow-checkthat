# Tasks

- [x] 1.1 `App.DB_REV`, `App.MIGRATIONS`, `App.Migrate`, called from `App.Init`, with log lines.
- [x] 1.2 Tests in `tests/test_app.lua`:
  - a 0.21.0-shaped table gets rev 1 and nothing else;
  - a second load changes nothing;
  - a migration runs once;
  - a newer rev is never lowered;
  - an unreadable value is left alone.
- [x] 1.3 Debug report line `Saved data: rev <n>`, with a test in `tests/test_log.lua`.
- [x] 1.4 Docs: `features.md`, `results-format.md`.
- [x] 1.5 Break each behavior once; each test failed.
