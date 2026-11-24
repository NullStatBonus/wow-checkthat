# Proposal

## Why

A plan today is a flat list of steps. A tester cannot pick part of a plan, and nothing shows where a run stands by area. Checks are limited to log lines and three probes, so a step cannot say "the fact is a number from 1 to 5", "this happened twice" or "no Lua error appeared". Authors who want unit-test coverage reach for WoWUnit. CheckThat should cover it alone: categories, a progress tracker, and the assertion types a unit test uses.

## What Changes

- **Categories.** A plan may declare `categories`. A step or section names one. Without declared categories, each section is a category, so every existing plan works unchanged.
- **Choose what to run.** The tester picks categories when starting a run, and can add one later. Steps in unpicked categories are `deselected`: not run, not counted as failures. `/ct run <category|step>` and the tracker jump to the first open step of a category. `/ct rerun <category>` reopens a finished category.
- **Progress tracker.** The card shows one segment per category and an overall bar. Blue: untested steps remain. Yellow: a partial or unverified step. Red: a step failed. Green: every step passed. Grey: only skips. Each segment also shows a count, so color is never the only signal.
- **Unit-test assertions.**
  - New `fact` assertion: typed values with `eq`, `ne`, `gt`, `ge`, `lt`, `le`, `between`, `approx` (with tolerance), `in`, `matches`, `contains`, `type`, `exists`, `missing`.
  - `count` (exactly, min, max) on `log` and `fact` assertions: "called exactly twice".
  - `quiet` log sources: silence is a valid result. CheckThat records Lua errors while a run is open into its own quiet `errors` source, so "no Lua errors" and "expects an error" work with no other addon.
  - Extra `state` operators: `ge`, `le`, `between`, `approx`, `matches`, `type`, `in`, `missing`.
  - Parameterized steps: `cases` expands one step into many when the plan compiles.
- **Existing plans and tests.** Plans compile unchanged. The self-test gains categories. `Run.Counts`, the report and the results string learn `deselected`. Tests, schema, README and docs change to match (see design).

## Capabilities

### New Capabilities

- `test-categories`: Grouping steps into categories, choosing categories to run, triggering and rerunning them, and the colored tracker.

### Modified Capabilities

- `test-plan-format`: Category declarations, `cases`, `count`, `quiet` and `field` on log sources, and the new assertion kind and operators.
- `run-evidence`: How `fact` assertions, counts and quiet sources are judged.
- `test-runner-ux`: The tracker on the card and category choice in the start flow.
- `slash-interface`: `/ct run`, `/ct rerun` and `/ct categories`.
- `test-plan-authoring`: Compile merges section categories and expands `cases`.
- `run-verification`: The report and results string show categories and deselected steps.

## Impact

- Addon code: `Model/Plan.lua`, `Model/Run.lua`, `Model/Evidence.lua`, `Model/App.lua`, `UI/Card.lua`, `Options/Options.lua`, `Core/Slash.lua`, `Locales/`. Version 0.10.0.
- Tools and schema: `tools/ct.py`, `schema/test-plan.schema.json`, `plans/*.yaml`.
- Tests and docs: every test file named in design; README, `docs/features.md`, `authoring-plans.md`, `listing.md`, `test-plan.md`, `contracts.md`; `/ct` command list.
- Saved data: additive. `ct` stays 1. A run without `selected` means every category.
