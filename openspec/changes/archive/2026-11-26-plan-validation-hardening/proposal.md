# Proposal

## Why

A code review of the plan format and its validators found five defects:

1. A plan pattern can freeze the game client. Lua patterns backtrack, and the game cannot stop `string.find` once it runs long. `.-.-.-Z` costs 0.37 s on a 200-character line and `.-.-.-.-Z` costs 15 s. The card checks twice a second and opens again after `/reload`, so the freeze returns.
2. `ct.py` accepts and encodes `null` (an empty YAML `value:`). The addon's JSON reader refuses it, so the import fails with "The string is damaged or incomplete".
3. `Plan.Validate` misses type checks. A hand-made string imports, is stored, then raises an error on every card refresh.
4. The schema accepts empty text that the addon rejects: step title and expect, action text, a fact's addon and key.
5. `ct.py compile` has no check for the 120000-character import cap, so it writes a string the game refuses.

## What Changes

- **Patterns run in a matcher that stops.** `Model/Pattern.lua` is a plain-Lua port of the Lua 5.1 matcher. It finds what `string.find` finds, on the whole line, and counts its steps; a simple pattern on a short line runs `string.find` itself. A match over the budget (40000 steps, 2 to 7 ms) leaves the line unchecked, and one evaluation may spend about 20 ms on lines it has not seen (the rest is "still checking the log" until the next refresh). A check that needed that line is unverified with "a log line took too long to check with this pattern", never pass and never fail. The answer for each pattern and line is cached for the card refresh.
- **Validation refuses only a pattern `string.find` raises on**, and a pattern over 200 characters: `Plan.PatternProblem` and its mirror `pattern_problem` in `tools/ct.py`, applied to log patterns, sequence items and `matches` values at import, `ct.py validate` and `ct.py compile`. Every other pattern keeps working. A stored plan with such a pattern is not run (unverified).
- `ct.py validate` refuses `null` anywhere in a plan, with its path. The schema types `value`.
- `Plan.Validate` checks the type of every field the card and the evidence code index, so such a plan is refused at import and never stored.
- The schema requires non-empty step `title`, `expect`, action `text`, and fact `addon` and `key`.
- `ct.py compile` fails above the 120000-character import cap.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-format`: a pattern must be one Lua can read; no `null`; empty required text is refused.
- `plan-transport`: import refuses a wrong-typed field; compile refuses a string over the import cap.
- `run-evidence`: patterns run with a step budget.

## Impact

- `CheckThat/Model/Plan.lua`, `CheckThat/Model/Pattern.lua` (new, in both TOC files), `CheckThat/Model/Evidence.lua`, `CheckThat/Model/App.lua` (a player sentence), `tools/replay_sv.lua`, `tests/harness.lua`.
- `schema/test-plan.schema.json`, `tools/ct.py`.
- `tests/test_plan.lua`, `tests/test_pattern.lua`, `tests/test_evidence.lua`, `tests/test_app.lua`, `tools/test_ct.py`, `tests/pattern_problems.lua`, `tests/fixtures/parity-bad.json`, `tests/fixtures/parity-patterns.json`, `tests/fixtures/bad-pattern.ct`.
- `docs/features.md`, `docs/authoring-plans.md`, `docs/test-plan.md`, `skills/ct-test-plan/SKILL.md`, `CHANGELOG.md`.
- The version stays 0.21.0, which is not tagged yet.
