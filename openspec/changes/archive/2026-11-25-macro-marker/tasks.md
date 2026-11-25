# Tasks

## 1. The marker command

- [x] 1.1 Add `App.MacroRun(id)` in `Model/App.lua` and the `macrorun` subcommand in `Core/Slash.lua` (one argument, usage line when missing, not in `noArgs`). Tests in `tests/test_app.lua` and `tests/test_slash.lua`: match logs `macro run` and prints nothing, mismatch logs `macro stale` with the chat line, none-open case, missing argument. Break the comparison, see them fail, restore it.
- [x] 1.2 Add the `L[...]` strings and the README row, the "Runs:" help text and `docs/features.md` text. `tests/test_readme.lua` and `tests/test_locale.lua` pass.

## 2. The macro body

- [x] 2.1 Add `Card.MacroBody`: marker, then commands, or `/ct status`; fall back when a result command is present or the body exceeds 255 characters; no marker with no step. `MakeMacro`, `FollowMacro` and the card hint use it. `Run` still uses `MacroText`.
- [x] 2.2 Update the follow tests in `tests/test_combat.lua` for the marker, and add cases: a press on the right step logs `macro run`, a step change in combat then a press logs `macro stale`, setting off then a press logs `macro stale`, a KeepThat step has the marker, a body near 255 falls back with the card line, Run logs no `macro run`. A press feeds each body line through `/ct`.

## 3. Plan and docs

- [x] 3.1 Rework `plans/checkthat-0.20.yaml` so each follow step asserts `[ct] macro run <step id>` (attempt scope), `afteroff` asserts the stale line, and `edit` and `kept` assert no `macro run`. Soften the Run caveat. Validate, compile and replay; update the trace count in `tests/test_replay.lua`.
- [x] 3.2 Update the README "Good to know" entry, `docs/features.md`, check 3.17 in `docs/test-plan.md` (Log line), the 0.20.0 changelog line and the PR body. `make test` and `make check` pass.

## Workflow follow-up

- Open an issue for stale presses on the run record, name it in Non-Goals, then archive.
