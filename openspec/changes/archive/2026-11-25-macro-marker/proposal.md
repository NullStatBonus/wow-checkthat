# Proposal

## Why

The CT macro (change `macro-follow`, #103) runs a step's commands, but nothing says the macro was pressed, or for which step. A plan cannot tell the macro from the Run button, and a stale macro (after combat, with the setting off, or after a player edit) looks like a correct press. The tester and the plan reviewer need to see a press that is out of sync or made in error.

## What Changes

- The CT macro starts with a marker line, `/ct macrorun <step id>`, then the step's commands. `/ct macro` and the follow setting build the same body. The Run button does not get the marker.
- New subcommand `/ct macrorun <step id>` compares the id with the step on the card. A match logs `macro run <id>` and prints nothing. A mismatch prints one chat line and logs `macro stale <macro id> card <current id>`. It never records a result.
- A step with no usable commands gets the marker and `/ct status`. When the marker and the commands together exceed the macro length limit, the step gets the marker and `/ct status`, and the card says the step has no macro.
- A macro with no marker (the player removed it) logs nothing, so a plan can tell an edited macro from a pressed one.
- Plan `plans/checkthat-0.20.yaml` asserts `macro run <step id>` for each key press. The CheckThat 0.20.0 changelog line mentions the marker.

A macro cannot stop its other lines from running, so a stale press still runs its commands. The marker makes the mismatch visible.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `test-runner-ux`: the macro body, the no-macro line, and a requirement for the press check.
- `slash-interface`: the `macrorun` subcommand.

## Impact

- `CheckThat/Core/Slash.lua`, `CheckThat/Model/App.lua` (`MacroRun`), `CheckThat/UI/Card.lua` (body builder).
- Docs: README, `docs/features.md`, `docs/test-plan.md`. Plan and replay count.
- Addon code changes, but 0.20.0 is not yet released or tagged, so the version stays 0.20.0 and the changelog line grows.
