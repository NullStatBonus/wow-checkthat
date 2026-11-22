# Proposal

## Why

The three sibling addons share one standard: AGENTS.md/CLAUDE.md/DESIGN.md, an Ace3 addon with AceDB profiles, an AceConfig standalone settings window with the same pages and sizing, a common slash vocabulary, a copyable debug report, an adapter for game calls, English-key localization, and TOC/embeds/version checks. TestThat was built as plain frames and global saved variables, so it breaks that standard.

## What Changes

- Add AGENTS.md, CLAUDE.md, DESIGN.md, CONTRIBUTING.md, CHANGELOG.md, LICENSE, THIRD_PARTY.md and docs/ (listing, localization, publishing, contracts, test-plan) in the sibling style.
- Rebuild the addon on Ace3: AceAddon, AceEvent, AceConsole, AceDB (shared Default profile, optional character profile), AceGUI/AceConfig settings.
- Settings: standalone window 600 x 460 with a tree and pages Home, Plans, Appearance, Advanced, About, plus Blizzard Settings entries.
- Slash vocabulary: settings, help, status, get/set, debug, log, log clear, with the runner commands added.
- Move game API reads into Core/Adapter.lua; add Debug/Log.lua and Debug/Export.lua; add Locales/enUS.lua with English keys.
- Add make check scripts for TOC, TOC match, embeds and version.
- Tests become tests/test_<module>.lua, each runnable alone, plus locale, readme, settings and options tests.
- Saved variables move to `WoWTestThatDB.global` (plans, runs, log); the collector and self-test plan follow.

## Capabilities

### New Capabilities
- `addon-settings`: standalone settings window, pages, scope, controls, Blizzard entries
- `slash-interface`: command vocabulary and validated get/set keys
- `debug-tools`: bounded debug log and copyable report

### Modified Capabilities
- `run-evidence`: log source path for WTT's own log
- `test-plan-format`: share points on steps and sections
- `test-runner-ux`: note box and share points

## Impact

Whole addon tree; tools/wtt.py collect; plans/selftest.yaml; tests; repo docs. Version 0.1.0 to 0.2.0. No change to the plan format or the string transport.
