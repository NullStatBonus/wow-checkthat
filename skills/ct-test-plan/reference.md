# Depth checklist

Read the format files for rules. This list is for judging a draft.

Sources: `schema/test-plan.schema.json`, `openspec/specs/test-plan-format/spec.md`, `docs/test-plan.md`, `tools/ct.py`, `Plan.SLASH` in `CheckThat/Model/Plan.lua`.

## Coverage
- Each changed requirement or scenario has at least one step.
- The nearest unchanged behavior has a regression step.
- Negative cases exist (bad input, disabled setting, missing data).
- Combat, protected-action and reload cases exist when the scope touches them.
- Steps for one client carry a `clients` tag; shared behavior runs on both.

## Assertions
- The first step checks the version under test (`/ct version` and a `version` fact with `op: ge` for CheckThat).
- A required assertion backs every step where the addon logs the evidence.
- `absent` checks cover "must not happen".
- `scope` fits the step. Use `attempt` for evidence expected after the step opens; attempts survive `/reload`. Use `session` only for a line an earlier step wrote.
- Assertion labels read as a result, not a log line.
- No step asks the player to read a log line.
- Steps with no log evidence use `verify: [player]`; the gap is listed for an issue.

## Evidence quality
Judge each log assertion against `docs/debug-logging.md`.
- The line states one fact with the values that prove it, and the code writes it at the decision point.
- A refusal, skip or failure has its own line, so `absent` and negative steps can pass or fail.
- The assertion matches the stable part of the line, not changing values.
- A required assertion backs an unconditional line.
- No startup line (such as `hooked ...`) stands in for a step result.
- Steps that wait for a missing log line carry a `notes` entry saying which line.

## Commands (`validate` warns about misses)
- Every slash command in step text appears in `action.commands`.
- Each command is in the addon's allow list, or is `/reload`, `/reloadui` or `/console scriptErrors 0|1`.
- No `/script`, `/run` or `/dump`. The card shows four command lines; keep a step to four.

## Character roles
- A check that needs more than one character is split into one plan for each role. No plan needs a login as another character.
- File names are `<name>.<role>.yaml`.
- Each preamble names every partner plan file.
- A `reviewer` line names the partner files, the step IDs to compare and the relationship that must hold. A step ID is always paired with a file name.
- Each role plan is compiled and validated. The import order is one role per character.

## Facts
- A step that asserts on a fact lists the `facts` log source (`global: CheckThatDB`, `path: global.facts`, `format: strings`) in the plan's `logs`.
- The asserted line is `[addon] key=value`, the same text the addon's `CheckThat.Report` call produces. The plan notes which addon change adds the call until it ships.

## Shape and wording
- One action and one expected result per step. A step with several actions or results exists only because the author asked for it, and carries `notes: Compound step, drafted on request.`
- A sample plan has a handful of steps; a release plan has more.
- Native color codes only. No backticks or `**`.
- Short sentences, active voice, one fact each.
- `setup` and `cleanup` exist where a step changes state. Shared `requires`, `setup` and `clients` sit on the section.
- Step ids are stable and prefixed per addon.

## Share points
- The preamble names the debug command and the `/reload` to run first.
- The handoff tells the tester how to export the result.
