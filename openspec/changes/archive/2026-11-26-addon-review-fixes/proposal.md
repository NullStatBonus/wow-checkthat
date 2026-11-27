## Why

A code review of the addon found one privacy gap and several small defects:

- A plan can read any global of any addon, and what it reads goes into the results string. The tester does not see that before the run starts.
- A reload while the card shows a past run does not mark the character's open run as reloaded. A `reload: after_action` step then asks for a second reload and an automatic step waits.
- `/ct categories` prints a raw `|` from a category title.
- Two code comments say CheckThat loads before the addons that register. `OptionalDeps` makes it load after them.
- Smaller gaps: the Categories window keeps the old profile's place after a profile switch, the `/ct start` addon list repeats `Plan.SLASH` and is case sensitive, the `/ct pass` line puts English words into one sentence, `.pkgmeta` ships two root files, and two comments and a dead assignment are left over.

## What Changes

- The card's start screen lists the variables the plan reads (each log source's `global` and each `global-value` check's name). The debug report shows `Plan reads:` for the run on the card. This is additive: no plan stops working.
- A reload marks the open attempt of the character's open run, and the resume lines name that run. A past run on the card is not reported as resumed.
- `/ct categories` doubles a bar in a title. Tooltips keep the raw text.
- The comments name the real load order.
- A profile switch moves the Categories window as well as the card.
- `/ct start` derives its addon list from `Plan.SLASH` and takes the name in any letter case.
- The `/ct pass`, `partial`, `fail` and `skip` line words each result and evidence word through `L[]`.
- `.pkgmeta` ignores `requirements-tui.txt` and `THIRD_PARTY.md`. A Python test fails when a root file is neither ignored nor meant to ship.
- Cleanup: a duplicated comment in `Evidence.lua` and a dead assignment in `Run.Undo` (no change of behavior).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `run-lifecycle`: a reload marks the character's open run, not the run the card shows.
- `slash-interface`: `/ct categories` escapes bars, `/ct start` is case-insensitive and follows `Plan.SLASH`, the verdict line is localizable.
- `test-runner-ux`: the start screen lists what the plan reads, and a profile switch moves the Categories window.
- `debug-tools`: the report lists what the plan of the run reads.

## Impact

- `CheckThat/Core/Addon.lua`, `Core/Slash.lua`, `Model/App.lua`, `Model/Run.lua`, `Model/Evidence.lua`, `Model/Entries.lua`, `Model/RunEvents.lua`, `UI/Card.lua`, `Debug/Log.lua`, `.pkgmeta`.
- Tests: `test_lifecycle`, `test_slash`, `test_tracker`, `test_app`, `test_card`, `test_log`, `tools/test_ct.py`.
- Docs: `README.md`, `docs/features.md`, `docs/authoring-plans.md`, `docs/test-plan.md`, `docs/publishing.md`, `CHANGELOG.md` (0.21.0).
- The version stays 0.21.0, which is not tagged yet.
