# Proposal

## Why

The name TestThat is not permitted on the addon site: names that contain "Test" are prohibited. The addon needs a new name that ends in "That", like its siblings KeepThat and DontDoThat. The new name is CheckThat.

## What Changes

- The addon, its folder, both TOC files, the settings window, the card, the debug report, the docs and the listing text say **CheckThat**. The TOC keeps its project IDs.
- The slash command is `/ct` with the long form `/checkthat`. `/wtt` is removed.
- The saved variable is `CheckThatDB`.
- Plans for the runner itself use the addon name `CheckThat`.
- The harvest tools read `CheckThat.lua` saved-variable files.
- Version 0.5.0.

No compatibility code: nobody has installed the addon yet. After the first release, a rename would need a saved-data copy and an alias.

Not renamed, by decision: the plan format identifiers (`!WTT1!`, `wtt: 1`, `.wtt` files, the `[wtt]` debug-log prefix, the `WTT` macro name, `tools/wtt.py`, the `wtt-test-plan` skill, `Copy-WttEvidence`). They name the plan format, not the addon, so existing plan strings and sibling plans keep working.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `addon-settings`: window title and name.
- `slash-interface`: `/ct` and `/checkthat`; every `/wtt` example becomes `/ct`.
- `debug-tools`: the report command and name.
- `run-evidence`: the saved variable name; the report label "recorded by CheckThat".
- `test-runner-ux`: card banner and wording.
- `test-plan-authoring`: the skill asks for the CheckThat checkout.
- `test-plan-format`: the runner's own plans name CheckThat and allow its commands.

## Impact

- Code: every file under the addon folder, which moves from `TestThat/` to `CheckThat/` (TOC files renamed with it); `Core/Slash.lua`, `Model/Plan.lua`, `tools/wtt.py`, `tools/Copy-WttEvidence.ps1`, `.pkgmeta`, `Makefile`, `tools/check-*.sh`, `plans/selftest.yaml`, the schema.
- Docs: README, `docs/`, `DESIGN.md`, `AGENTS.md`, `CONTRIBUTING.md`, `THIRD_PARTY.md`, the skill. Archived changes and past changelog entries keep the old name.
- Tests: every test that names the addon, its saved variable or its global frames; new tests for the two commands and the runner plan's commands.
- The GitHub repository is renamed by hand after this change is committed. Docs that name the repository use `wow-checkthat`.
- Addon code changes, so the version rises: 0.5.0. A player-visible rename with a new command is a minor bump before 1.0.
