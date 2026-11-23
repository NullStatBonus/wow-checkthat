## Why

A run stays active until every step resolves or the player starts another run. A player cannot stop a half-done run and start fresh, or mark it ended in the report. See GitHub issue 35.

## What Changes

- **End run** action in a header menu on the card. The "CheckThat / Run" label becomes a clickable "Run" menu in both the expanded and the collapsed card.
- **Confirmation** before the run ends. Every end asks, even with no step resolved.
- **Ended run**: results stay. Pending and unverified steps stay as they are. The run is marked ended and cannot resume. Undo and Resume are off for it.
- **`/ct end`** runs the same confirmation and the same code path as the menu item.
- The report and `/ct log` show the ended state. The exported results mark the run ended, even when every recorded verdict passed.
- README, `docs/listing.md` and `docs/test-plan.md` cover the new action and command.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `test-runner-ux`: header menu with End run, confirmation, ended-run card state.
- `slash-interface`: new `end` runner command.
- `run-evidence`: ended runs keep results, stay marked ended in saved data and export, and take no new verdicts.

## Impact

- Addon code: `CheckThat/UI/Card.lua`, `CheckThat/Model/Run.lua`, `CheckThat/Model/App.lua`, `CheckThat/Core/Slash.lua`, `CheckThat/Core/Adapter.lua` (menu helper, guarded). New strings use `L[]`.
- Version bump (patch or minor per `AGENTS.md`) and a changelog entry at archive.
- Saved data: an optional run-level `endedAt`. Older saves omit it. No migration.
- Docs: `README.md`, `docs/listing.md`, `docs/test-plan.md`. Update `schema/test-plan.schema.json` only if the plan format changes. It does not.
