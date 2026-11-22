## Context

KeepThat is the reference implementation (DESIGN.md, AGENTS.md, Options.lua, Slash.lua, Defaults.lua). TestThat copies its structure, not its feature code.

## Decisions

- **Layout**: Core/ (Init, Adapter, Defaults, Settings, Addon, Slash), Model/ (Json, Codec, Plan, Evidence, Run, App: plain Lua, no game globals), UI/Card.lua, Options/Options.lua, Debug/ (Log, Export), Locales/enUS.lua, Libs/.
- **Saved data**: AceDB `WoWTestThatDB`. profile = appearance and card state; global = plans, planStore, runs, currentByChar, log. No migration code: version 0.1.0 was never shipped.
- **Log**: Debug/Log.lua records `[wtt] ...` entries into global.log.entries; recording follows profile.debug. App calls Log.Record, so the self-test plan reads `global.log.entries`.
- **Adapter**: Core/Adapter.lua exposes Env() (the table the Model uses for game reads: GetBuildInfo, UnitName, time, IsAddOnLoaded, plus read-only access to other addons' globals) and InCombat, Reload, macro helpers.
- **Settings keys**: shared validators in Core/Settings.lua used by Options and Slash.
- **Tests**: harness.lua builds a fake client; each test_*.lua runs standalone; run.lua runs each in its own process.
- **Strings**: every player-facing sentence is L["English sentence"]; debug output stays English.

## Non-Goals

- Move/Done/Cancel positioning transaction (the card is dragged; lock and reset exist); presets; translations.
