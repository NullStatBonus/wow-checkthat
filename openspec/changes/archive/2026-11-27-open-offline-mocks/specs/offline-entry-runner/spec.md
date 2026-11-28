## MODIFIED Requirements

### Requirement: Only listed APIs can be mocked
The runner SHALL hold a closed list of mockable API names, and below offline level 5 a mock SHALL name a function on that list. At level 5 and up a mock MAY also name any function the client's surface lists, except Lua's own functions (the base library, the `string`, `table`, `math`, `bit`, `coroutine`, `os`, `io`, `debug` and `jit` tables, and the game's aliases of them such as `strsub`) and the functions the fake client's security, combat and timer model rests on (`CreateFrame`, `hooksecurefunc`, `issecurevariable`, `issecure`, `securecall`, `securecallfunction`, `secureexecuterange`, `forceinsecure`, `InCombatLockdown`, `RunScript`, `seterrorhandler`, `geterrorhandler` and `C_Timer`). Any other mock SHALL stop the run before the addon loads and fail with the name and "is not on the allow list". A plan cannot add to either rule.

#### Scenario: Unlisted mock
- **WHEN** a plan mocks `loadstring`, at any level
- **THEN** the run fails before any addon file loads and nothing is replaced

#### Scenario: A surface function at level 5
- **WHEN** a level 5 block on an Era TOC mocks `GetSpellInfo`, which the closed list does not name, and the same mock runs at level 4
- **THEN** the level 5 run calls the mock, and the level 4 run fails with "mock GetSpellInfo is not on the allow list"

#### Scenario: The fake client's model
- **WHEN** a level 5 block mocks `InCombatLockdown`, `hooksecurefunc` or `C_Timer.After`
- **THEN** the run fails before load with "is not on the allow list"

## ADDED Requirements

### Requirement: Runner reads the addon's own recordings
At level 5 a block MAY name a `recordings` folder. The runner SHALL read `<folder>/<client>.json` for the client the TOC names, beside `tools/recordings/<client>.json`. A label in both SHALL take the addon's entry. A missing file in the folder SHALL add nothing. A file that cannot be read, or has a format other than 1, SHALL fail the load step with its path. A `recording` mock that matches neither file SHALL fail with both paths.

#### Scenario: A recording from the addon
- **WHEN** a level 5 block names a folder whose `era.json` records `GetSpellInfo(133)`, and mocks `GetSpellInfo` with `recording: GetSpellInfo(133)`
- **THEN** the mock answers the recorded values

#### Scenario: The addon's entry wins
- **WHEN** the addon's file and the bundled file both record `GetItemInfo(6948)` with different names
- **THEN** the mock answers the addon's name
