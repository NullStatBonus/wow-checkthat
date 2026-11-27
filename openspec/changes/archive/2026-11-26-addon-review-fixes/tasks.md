## 1. Addon

- [x] 1.1 Reload marks the character's open run; resume lines name it (`Addon.lua`, `App.lua`)
- [x] 1.2 `/ct categories` escapes a bar; `/ct start` follows `Plan.SLASH` and ignores case; the verdict line uses `L[]` words (`Slash.lua`)
- [x] 1.3 Start screen note, `App.PlanReads`, `App.ReadsNote`, `Plan reads:` in the report (`App.lua`, `Card.lua`, `Log.lua`)
- [x] 1.4 A profile switch moves the Categories window (`Card.lua`)
- [x] 1.5 Comments in `Entries.lua` and `RunEvents.lua`; duplicate comment in `Evidence.lua`; dead assignment in `Run.Undo`
- [x] 1.6 `.pkgmeta` ignores the two root files; Python test for the root files

## 2. Tests

- [x] 2.1 Lua tests for each behavior, each broken once and restored
- [x] 2.2 `tools/test_ct.py` root-file test

## 3. Docs

- [x] 3.1 README, `docs/features.md`, `docs/authoring-plans.md`, `docs/test-plan.md` (3.23 and 4.15), `docs/publishing.md`
- [x] 3.2 `CHANGELOG.md` 0.21.0 lines
- [x] 3.3 `make test` and `make check`
