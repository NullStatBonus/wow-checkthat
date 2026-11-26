## MODIFIED Requirements

### Requirement: Runner answers by the plan's offline level
The offline block MAY declare `level`, 1, 2, 3, 4 or 5. A block without `level` SHALL run at level 1, so its results do not change: `GetBuildInfo` returns interface 11507 and `issecurevariable` returns false for every name. At level 2 and above the runner SHALL make `GetBuildInfo` return, as its interface number, the number on the TOC's `## Interface:` line, and the key SHALL count only at the start of a line, so the same text inside another line, such as `## Notes:`, is ignored. When the line lists several numbers, the first one SHALL be used. At level 2 and above `issecurevariable` SHALL return true for each global the fake client set up before addon code ran, and false with "Addon" for any other global. Level 3 SHALL add the game's load order (see "Level 3 loads the addon as the game does"), level 4 the event list and the clock (see "Level 4 checks events against the client" and "Level 4 runs timers on a virtual clock"), and level 5 the client's surface (see "Level 5 gives the client's real surface"). Any other `level`, a `reload` step, `groups` or `savedVariables` below level 3, and a `wait` step below level 4, SHALL fail the load step and no addon file SHALL run. The JSON result SHALL carry the level and the interface the addon read. `ct.py offline` SHALL print a warning to stderr when the block has no `level`.

#### Scenario: Era and Forever interfaces at level 2
- **WHEN** a block with `level: 2` names a TOC that says `## Interface: 11509`, and another names one that says `## Interface: 16001`
- **THEN** the addon reads 11509 in the first run and 16001 in the second, and the JSON result carries that number

#### Scenario: Block without a level
- **WHEN** a block has no `level`
- **THEN** the addon reads interface 11507, `issecurevariable("CreateFrame")` is false, and `ct.py offline` prints the level warning

#### Scenario: Unknown level
- **WHEN** a block says `level: 6`
- **THEN** the load step fails with "offline level 6 is not supported" and no addon file runs

#### Scenario: Reload below level 3
- **WHEN** a block at level 2 holds a `reload` step
- **THEN** the load step fails and no addon file runs

#### Scenario: Level 2 sends no login events
- **WHEN** a block at level 2 fires ADDON_LOADED in an `event` step
- **THEN** the handler runs once, and `IsLoggedIn()` is true during load

#### Scenario: Wait below level 4
- **WHEN** a block at level 3 holds a `wait` step
- **THEN** the load step fails with "a wait step needs offline level 4" and no addon file runs

## ADDED Requirements

### Requirement: Level 5 gives the client's real surface
At level 5 the runner SHALL build the fake client with the surface of the client the TOC's interface names, `tools/clients/era.json` below 16000 and `tools/clients/forever.json` from 16000, and a missing surface SHALL fail the load step. Only the surface's global functions and `C_` functions SHALL exist. A function the surface lists that the fake client does not model SHALL be a stub that returns nothing, and a Lua alias such as `strsub` or `tinsert` SHALL be the Lua function. `GetBuildInfo` SHALL return the surface's build and interface. A frame of a listed widget type made without a template SHALL have only that type's methods. A mock of a function the surface lacks SHALL fail the load step before any addon file runs.

#### Scenario: Function only on another client
- **WHEN** a level 5 block names a Forever TOC
- **THEN** `GetItemInfo` is nil and `C_Item.GetItemInfo` is a function

#### Scenario: Method typo
- **WHEN** addon code at level 5 reads `SetPointt` on a frame made with `CreateFrame("Frame")`
- **THEN** it reads nil, and at level 4 it reads a function

#### Scenario: Mock of a missing function
- **WHEN** a level 5 block on a Forever TOC mocks `GetItemInfo`
- **THEN** the load step fails with "mock GetItemInfo: the forever client has no such function"

### Requirement: CheckThat runs on both client surfaces
`make test` SHALL load CheckThat's Vanilla TOC under the Era surface and its Camelot TOC under the Forever surface, enable it, start and step through a plan and export it.

#### Scenario: Both clients
- **WHEN** `tests/test_clients.lua` runs
- **THEN** CheckThat loads and runs a plan under each surface, and `GetBuildInfo` gives that client's interface
