## Why

Issue #244: a plan could name only four addons (`Plan.SLASH`, the schema enum, `ct.py`, `/ct start`). The docs, the skills and the public listing invite any addon. The `addon` enum is part of the plan format, so it must open before 1.0, and it must open without letting an imported plan run another addon's or the game's commands.

## What Changes

- **Any addon.** A plan names any addon by its folder name. The four built-in addons keep their command lists.
- **`commands` plan key** (plan revision 2). It lists the addon's own command prefixes, at most 8, one word each. `/run`, `/script`, `/dump`, `/console`, the game's debug commands, `/macro`, `/logout`, `/quit`, `/camp` and another known addon's commands are refused, in `ct.py` and on import.
- **Owned in game.** A listed prefix is offered as a Run button or in the CT macro only when the addon under test wrote its `SLASH_` global. `Adapter.SlashOwner` reads the writer through `issecurevariable`. The start screen, the start log line and the debug report say what is offered and what is not.
- **Declared by the addon.** `CheckThat.Commands(addon, list)` declares the addon's commands, and they are offered without the ownership check. `API_VERSION` becomes 4.
- **`/ct start`** accepts the addon of any imported plan.
- **`ct.py`.** `validate` and `compile` (which writes `needs: 2`), plus `from-md` and `coverage`, work for any addon.
- Schema, specs, docs (README, `authoring-plans.md`, `adopting.md`, `contracts.md`, `features.md`) and the plan skill.

## Capabilities

### Modified Capabilities
- `test-plan-format`: any addon, `commands`, and offering only owned commands.
- `slash-interface`: `/ct start` for any imported plan.
- `entry-calls`: `CheckThat.Commands`.

## Impact

Addon code, `tools/ct.py`, the schema, tests, docs and the skill.

Compatibility is additive. Every plan that validated still validates, and its compiled string is unchanged, because `needs` is written only with `commands`. An older CheckThat refuses a plan with `commands` ("needs a newer CheckThat"), and still refuses a plan for an unknown addon without it ("addon not supported"). The self-test plan's API version check moves to 4.

The version bump is held per the release hold.
