## Why

The skill's depth question offers "sample or release plan", then splits a large scope into a plan set by area and tells the author to run every plan before each release (#219). For ClosestVendor that gave three plans of 53 steps. About 10 of them needed a class, a profession, a dungeon, a fight or another addon, so no single character could run the release gate. The steps also read as technical: slash commands in the action text, "the addon logs" in Expect, and steps that only put a setting back.

## What Changes

- The `ct-test-plan` interview asks first what the plan is for: a **foundation plan** (the release gate) or a **feature plan** (deep on one feature). This replaces "sample or release plan".
- **Foundation plan:** the skill finds the pillars (the systems every feature depends on) and each pillar's real-game risk before it drafts. The plan is runnable by one stated character (any class, any level, no profession, one place), one run per client, with about one step per pillar (8 to 12 steps). Steps that need a class, profession, place, fight or other addon leave the gate, and the preamble names where each goes.
- **Feature plan:** deep on one feature (edge cases, negative cases, each client, one plan per role). It runs when the feature changes, not before every release. The skill asks whether to retire it or keep it as a regression plan.
- **Wording rules for both:** action text is one player-language sentence with commands only behind Run, and Expect says what is on screen, never what is logged.
- **Plan format:** an optional, tools-only `purpose: foundation | feature` key on the plan. The compiler drops it. A plan that declares it gets new `validate` warnings: a slash command in action text or Expect, the word "log" in Expect, and (foundation only) more than 12 steps. A plan without `purpose` gets no new warning.
- The skill sets `purpose` on every new plan. Its review checks the single character and the pillars of a foundation plan. "Plan sets by area" is no longer the release gate.
- `docs/authoring-plans.md`, `docs/skills.md`, the skill's `reference.md` checklist and `example.yaml` follow.

## Capabilities

### New Capabilities

### Modified Capabilities

- `test-plan-format`: a plan may declare its purpose; validation warns about technical wording and a long foundation plan in a plan that declares one.
- `test-plan-authoring`: the depth question becomes "foundation or feature"; the skill drafts a foundation plan from pillars for one character and a feature plan deep on one feature; plan sets by area are not the release gate.

## Impact

Tools, skill, schema and docs only: `tools/ct.py`, `tools/test_ct.py`, `schema/test-plan.schema.json`, `skills/ct-test-plan/`, `docs/authoring-plans.md`, `docs/skills.md`, `openspec/specs/`. No file under `CheckThat/` changes, so no version bump. The compiled plan string is unchanged. Existing plans keep their validate output and exit codes.
