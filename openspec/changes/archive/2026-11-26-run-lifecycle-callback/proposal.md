## Why

An addon that isolates its state for a test run cannot restore it when the run stops early. CheckThat gives addons no signal when a run ends, is replaced or is deleted. ClosestVendor's `/cvn testsettings` stays on until the tester types `off` (see #171, #167).

## What Changes

- Add `CheckThat.OnRun(addonName, fn)`. CheckThat calls `fn("start", info)` and `fn("end", info)` for runs of a plan that names that addon.
- Add `CheckThat.ActiveRun(addonName)`. It returns the open run's plan name, or nil. An addon uses it at login to restore state that a run left behind.
- Raise `CheckThat.API_VERSION` from 2 to 3. The change only adds to the API.
- Add debug log lines for each call, and a manual check.
- No version bump and no CHANGELOG entry. The user holds releases.

## Capabilities

### New Capabilities
- `run-lifecycle`: Addons learn when a run of their plan starts or stops being the open run, and can ask which run is open.

### Modified Capabilities
- `entry-calls`: the pinned `API_VERSION` becomes 3.
- `fact-reporting`: "The API only grows" names version 3.

## Impact

- `CheckThat/Model/App.lua`: fire the callbacks at start, open, end, replace and delete.
- `CheckThat/Model/Facts.lua`: `Facts.API()` exposes `OnRun` and `ActiveRun`.
- A new model module holds the registry, like `Model/Entries.lua`.
- `docs/features.md`, `docs/contracts.md`, `README.md`, `docs/test-plan.md`, `docs/listing.md`.
- `tests/test_runcallback.lua` (new) and `tests/test_entry_api.lua`.
