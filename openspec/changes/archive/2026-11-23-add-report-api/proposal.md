# Proposal

## Why

A sibling addon cannot tell CheckThat what it did while the player tests. A plan can only read that addon's own debug log or saved variables, and only if the addon already writes them (issue #25). A small public function lets an addon publish a named fact the plan can check, and lets an auto step pass from it.

## What Changes

- Add a global `CheckThat` table with `CheckThat.Report(addon, key, value)` and `CheckThat.API_VERSION = 1`.
- `Report` records one line `[addon] key=value` in a bounded list in CheckThat's saved variables, only while a run is open.
- A plan reads the list as an ordinary log source (`global = "CheckThatDB"`, `path = "global.facts"`, `format = "strings"`). The plan format, schema and `tools/ct.py` do not change.
- `Report` accepts strings, numbers and booleans only. It limits name and value length and how many facts one addon can send. It never raises an error and does nothing when no run is open.
- The debug report counts the facts, and the debug log notes each accepted and dropped fact.
- The API only grows from here: names, argument order and the line format stay as released. An addon guards with `if CheckThat and CheckThat.Report then`.
- No new setting.
- The `ct-test-plan` skill offers a fact beside a new log line when a step has no evidence, and `docs/debug-logging.md` gets a "Publish a fact" section with the guarded call and naming rules. The bundle carries the guide.
- Docs in the restructured layout: one or two README lines, details in `docs/features.md` and `docs/authoring-plans.md`, the contract in `docs/contracts.md`, plus `docs/listing.md` and `docs/test-plan.md`.

## Capabilities

### New Capabilities
- `fact-reporting`: how a sibling addon publishes named facts into the evidence log, the limits on them, and how plans read them.

### Modified Capabilities
- `test-plan-authoring`: the skill's offer of issues for missing evidence names a fact as well as a log line.

Run evidence is unchanged. Auto steps and log assertions already work on any readable log.

## Impact

- New `CheckThat/Model/Facts.lua`, listed in both TOC files. A small export in `Core/Adapter.lua`, which is the only place that touches the game's global table. A call from `Core/Addon.lua`. A line in `Debug/Log.lua`.
- Addon code changes, so the version goes from 0.8.3 to 0.9.0 (new capability).
- Deferred and not built: callbacks or state snapshots from other addons. The API is data only, so imported data is never executed.
