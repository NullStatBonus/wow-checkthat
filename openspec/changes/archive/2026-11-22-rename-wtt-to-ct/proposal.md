# Proposal

## Why

The plan format, its tools and the log prefix still carry the old name: `WTT` stood for "WoW TestThat". The addon is now CheckThat and its short form is `ct`. Nobody has installed the addon, so there are no plan strings, saved runs or installed skills to keep working. Renaming now avoids an unexplained leftover name and a harder rename later.

## What Changes

Every `wtt` or `WTT` identifier becomes `ct` or `CT`:

- Plan and results strings start with `!CT1!` (was `!WTT1!`). The plan field `wtt: 1` becomes `ct: 1`, and results carry `ct = 1`. Compiled plan files end in `.ct`.
- Debug-log lines start with `[ct]` (was `[wtt]`). The macro the card creates is named `CT`, `CT2` to `CT9` (was `WTT`).
- `tools/wtt.py` becomes `tools/ct.py`, `tools/test_wtt.py` becomes `tools/test_ct.py`, and the environment variables `WTT_WTF` and `WTT_SHOTS` become `CT_WTF` and `CT_SHOTS`.
- The skill `wtt-test-plan` becomes `ct-test-plan`, and its install folder and marker file follow.
- The evidence scripts are `Copy-CheckThatEvidence.bat` and `tools/Copy-CheckThatEvidence.ps1` (a rename made locally earlier).
- A test fails if a tracked file outside history still uses the old names.
- Version 0.5.2.

No compatibility code: a string made with an earlier version is rejected as "not a CT string". Archived changes and older changelog entries keep the old names.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plan-transport`: the string prefix and version name.
- `run-evidence`: the evidence collector's command.
- `test-plan-authoring`: the skill name, tool names and install paths.
- `test-runner-ux`: the macro name.

## Impact

- Code: `CheckThat/Model/Codec.lua`, `Plan.lua`, `Run.lua`, `App.lua`, `CheckThat/UI/Card.lua`, `CheckThat/Options/Options.lua`, `tools/ct.py`, `schema/test-plan.schema.json`, `plans/**`, `Makefile`, `.gitignore`.
- Docs and skill: README, `docs/`, `AGENTS.md`, `CONTRIBUTING.md`, the skill folder.
- Tests: every test that names the format, the prefix or the tools; a new test for leftover names.
- Outside the repository: the parent folder's `Copy-CheckThatEvidence.bat` comments name `tools/wtt.py`.
- Addon code changes, so the version rises: a modification, so a patch bump (0.5.2).
- No design.md: a mechanical rename with the decisions stated above.
