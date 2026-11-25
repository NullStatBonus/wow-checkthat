# Proposal

## Why

The installed skills cannot do what an addon author needs. The bundle has no flow replay and no offline runner, so KeepThat ran the tools from a sibling checkout (#130). The replay writes only CheckThat's own log, so a plan for another addon needed 59 lines of hand-written hooks that copy the plan's own assertions (#130). The skills also lack the review gate, stable step ids and run-version checks that the 0.16 to 0.20 test cycles taught us (#134).

## What Changes

- The skill bundle ships the whole addon folder, the fake-client harness, the replay and the offline runner. `ct.py replay-flow` and `ct.py offline` run from the bundle with no checkout. `tools/ct` is a launcher; `make install-skill BIN_DIR=<folder>` writes a copy on the path.
- The flow replay writes each plan's own log source, from literal lines, patterns and sequences, so no hooks file is needed. It prints "evidence assumed" and reports a check it cannot derive.
- `ct.py lines` checks that each asserted log line and fact key appears in the addon's Lua source.
- `ct.py validate` warns about a manual step whose own commands move the card.
- `ct.py diff` marks a step that kept its text and changed its id as renamed, and warns that its history is split.
- `ct.py report` takes `--expect-version` and `--plan` and warns about a run of another addon version, another CheckThat version, or an older plan file.
- `ct-test-plan` gains a handoff gate, a step-id rule, an offline question and an optional pull request block. `ct-verify` reads saved variables first and relays the version warnings.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `plan-replay`: flow replay for any addon's plan, the line source check, the bundled tools.
- `test-plan-authoring`: the handoff gate, stable step ids, the offline question, the card-move warning.
- `run-verification`: version and digest warnings, saved variables before more steps.

## Impact

- `tests/replay.lua`, `tools/ct.py`, `tools/ct`, `Makefile`, `skills/ct-test-plan/SKILL.md`, `skills/ct-verify/SKILL.md`.
- Tests: `tests/test_replay.lua`, `tools/test_ct.py`.
- Docs: `docs/skills.md`, `docs/authoring-plans.md`, `docs/adopting.md` (new), the README developer commands.
- Review fixes (Codex and Opus): a failed step is now a replay problem; the plan's own addon counts as loaded; count checks and the log cap are honoured; `replay-flow` runs both clients; `lines` ignores comments and tests and tries the whole line first; report warnings are scoped to the plan's addon and title; `BIN_DIR` links the launcher and refuses unsafe paths.
- Command lint: a test checks every `ct.py <command>` named in the skills and docs exists. Flags are not linted yet.
- Tools and skills only. No file under `CheckThat/` changes, so no version bump.
- Not in this change: the addon-version probe (#105, a minor bump), revise mode (#131), golden scenarios (#133), the skill text split (#132).
