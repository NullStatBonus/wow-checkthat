## 1. Fix

- [x] 1.1 Compare macro bodies without trailing whitespace in `writeMacro`
- [x] 1.2 Take back a macro that holds only `/ct status` on a new run or when the setting turns on
- [x] 1.3 Return a reason on failure; log `macro not set <step id>: <reason>` once for each new reason; chat once when the game does not take an edit
- [x] 1.4 Tests in `tests/test_combat.lua`, each break-checked

## 2. Docs

- [x] 2.1 `docs/features.md` macro section and log lines
- [x] 2.2 `docs/test-plan.md` §3.17 covers a new run after an ended one
- [x] 2.3 `CHANGELOG.md` 0.21.0 Fixed line
