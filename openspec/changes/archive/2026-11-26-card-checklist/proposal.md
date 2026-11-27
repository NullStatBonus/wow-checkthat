# Proposal

## Why

The step card is crowded and hard to read. Plans pack several player actions into one Do sentence and several results into one Expect sentence, so the tester has to keep the whole sentence in mind (#218). Two banners, the section intro, a reload line and an always-open note box sit between the title and the result buttons. An automatic step that passes jumps straight to the next card, so the tester misses what happened. Some steps cannot apply to the character (#173), and some can be decided before their turn (#174), but today the tester waits on the card for both.

## What Changes

- **Do checklist (#218).** `action.text` may be a list of two to six actions. The card shows one real checkbox (`UICheckButtonTemplate`) per action, which the player ticks. The ticks are saved on the attempt. Pass does not wait for the ticks. A string `action.text` shows as today.
- **Expect list.** `expect` may be a list. The card shows it as short lines without boxes. A string shows as today.
- **The checks list stays as it is** (ready-check icons, "All checks detected. Press Pass.", countdown).
- **Calmer card.**
  - A small green "CheckThat checks" heading over the checks list replaces the green banner.
  - The gold "YOU CONFIRM THIS STEP" banner goes.
  - The section intro and preamble move into a Setup fold that opens by itself the first time.
  - The "Reloaded" line merges into the reload hint.
  - The note box sits behind "+ Add note".
  - The title is heavier.
- **Pause on an automatic result.** When CheckThat records a step itself, the card keeps showing that step with "Recorded: Pass (recorded by CheckThat)" and fades to the next step over 3 seconds. A press during the fade skips it.
- **Inapplicable by character (#173).** A plan requirement may name `class` tokens or `profession` names and set `unmet: inapplicable`. A step whose requirement is unmet when it opens is inapplicable, and the card says why. Without `unmet`, a requirement blocks as today.
- **Checked at run start (#174).** `async: true` on an automatic step: CheckThat judges it when the run starts. A pass is recorded then and the card skips the step. Otherwise it waits on its turn as today.
- Additive only. `Run.FORMAT_REV` rises once for the new attempt and step keys.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-format`: `action.text` and `expect` may be lists; `async` on auto steps; requirement `class`, `profession` and `unmet`.
- `test-runner-ux`: card layout, the checks heading in place of the banners, Setup fold, Add note, reload hint, title weight, the Do checklist and the pause after an automatic result.
- `run-evidence`: ticks saved on the attempt; run-start judgement for async steps; inapplicable by requirement.
- `test-plan-authoring`: the skill writes several actions as a list.
- `plan-replay`: replay-flow settles async steps at start and takes both branches of an inapplicable requirement.

## Impact

- `CheckThat/UI/Card.lua` (layout, checklist rows, fade), `Model/Plan.lua`, `Model/Run.lua` (Verdict, Begin, NextPending, FORMAT_REV), `Model/App.lua` (Start), `Model/Evidence.lua` (run-start judgement), `Core/Adapter.lua` (class and profession reads), `Locales/enUS.lua`.
- `schema/test-plan.schema.json`, `tools/ct.py` (validate, compile, report, show, replay-flow), `tests/replay_plan.lua`.
- `DESIGN.md` §3, `README.md`, `docs/features.md`, `docs/authoring-plans.md`, `docs/results-format.md`, `docs/test-plan.md`, `docs/listing.md`, skills.
- The version stays 0.21.0, which is not tagged yet.
