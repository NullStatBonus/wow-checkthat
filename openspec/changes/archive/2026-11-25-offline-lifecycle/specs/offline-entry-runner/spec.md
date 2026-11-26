## MODIFIED Requirements

### Requirement: Runner answers by the plan's offline level
The offline block MAY declare `level`, 1, 2 or 3. A block without `level` SHALL run at level 1, so its results do not change: `GetBuildInfo` returns interface 11507 and `issecurevariable` returns false for every name. At level 2 and above the runner SHALL make `GetBuildInfo` return, as its interface number, the number on the TOC's `## Interface:` line, and the key SHALL count only at the start of a line, so the same text inside another line, such as `## Notes:`, is ignored. When the line lists several numbers, the first one SHALL be used. At level 2 and above `issecurevariable` SHALL return true for each global the fake client set up before addon code ran, and false with "Addon" for any other global. Level 3 SHALL add the game's load order (see "Level 3 loads the addon as the game does"). Any other `level`, and a `reload` step, `groups` or `savedVariables` below level 3, SHALL fail the load step and no addon file SHALL run. The JSON result SHALL carry the level and the interface the addon read. `ct.py offline` SHALL print a warning to stderr when the block has no `level`.

#### Scenario: Era and Forever interfaces at level 2
- **WHEN** a block with `level: 2` names a TOC that says `## Interface: 11509`, and another names one that says `## Interface: 16001`
- **THEN** the addon reads 11509 in the first run and 16001 in the second, and the JSON result carries that number

#### Scenario: Block without a level
- **WHEN** a block has no `level`
- **THEN** the addon reads interface 11507, `issecurevariable("CreateFrame")` is false, and `ct.py offline` prints the level warning

#### Scenario: Unknown level
- **WHEN** a block says `level: 4`
- **THEN** the load step fails with "offline level 4 is not supported" and no addon file runs

#### Scenario: Reload below level 3
- **WHEN** a block at level 2 holds a `reload` step
- **THEN** the load step fails and no addon file runs

#### Scenario: Level 2 sends no login events
- **WHEN** a block at level 2 fires ADDON_LOADED in an `event` step
- **THEN** the handler runs once, and `IsLoggedIn()` is true during load

## ADDED Requirements

### Requirement: Level 3 loads the addon as the game does
At level 3 the runner SHALL read the names on the TOC's `## SavedVariables` and `## SavedVariablesPerCharacter` lines and set each to nil before the files run. After the last file it SHALL assign each name that `savedVariables` holds, and leave the others as the files set them. With `## LoadSavedVariablesFirst: 1` it SHALL assign them before the first file. A `savedVariables` name the TOC does not declare SHALL fail the load step. It SHALL then fire ADDON_LOADED with the addon's folder name, PLAYER_LOGIN, and PLAYER_ENTERING_WORLD with `true, false`, at each frame that registered the event. An event that no frame registered SHALL NOT fail the run. A handler that throws SHALL fail the load step with the event's name. `IsLoggedIn()` SHALL return false until PLAYER_LOGIN fires.

#### Scenario: File-scope write is lost
- **WHEN** an addon sets its saved variable at file scope and `savedVariables` holds a value for it
- **THEN** an entry called after load returns the saved value, not the file-scope value

#### Scenario: First login keeps the default
- **WHEN** `savedVariables` holds no value for a declared name
- **THEN** the value the file set is kept

#### Scenario: Login order
- **WHEN** an addon records the events it receives and `IsLoggedIn()` at each
- **THEN** it saw ADDON_LOADED with its folder name and `IsLoggedIn()` false, then PLAYER_LOGIN, then PLAYER_ENTERING_WORLD with `true, false`

### Requirement: Reload step loads the addon fresh
A `reload` step SHALL fire PLAYER_LEAVING_WORLD, PLAYER_LOGOUT and ADDONS_UNLOADING, then copy each declared saved variable as the game saves it: strings, numbers, booleans and tables with string, number or boolean keys, without functions, userdata, threads or metatables. Two references to one table SHALL come back as two tables, and a reference to a table that holds it SHALL be dropped. A nil name SHALL not be written. The runner SHALL then load the addon fresh: globals the addon set, its frames, its registered entries and its upvalues SHALL be gone. It SHALL assign the copies and fire the login events with PLAYER_ENTERING_WORLD `false, true`. Mocks SHALL be set again, and their counts SHALL go on.

#### Scenario: State survives only in saved variables
- **WHEN** an entry sets a saved variable and a local upvalue, and a reload step follows
- **THEN** a later call sees the saved value and the upvalue's first value

#### Scenario: Logout write is kept
- **WHEN** a PLAYER_LOGOUT handler writes to a saved variable
- **THEN** after the reload the addon reads that value

#### Scenario: A global that is not saved is gone
- **WHEN** the addon set a global that the TOC does not declare
- **THEN** after the reload that global is nil until the files set it again

### Requirement: Groups load the addon fresh
An offline block MAY hold `groups` in place of `steps`. Each group SHALL start from a fresh load with the block's mocks and its own added over them, and with its own `savedVariables` or else the block's. Mock counts SHALL start at zero in each group. Each step result SHALL carry its group number, and `ct.py offline` SHALL name such a step `offline.G.N`. A block without groups SHALL keep the names `offline.N`.

#### Scenario: Opposite mocks
- **WHEN** two groups mock the same API with opposite values and each checks its own
- **THEN** both groups pass

#### Scenario: State does not cross groups
- **WHEN** the first group sets a flag through an entry and the second reads it
- **THEN** the second group reads no flag
