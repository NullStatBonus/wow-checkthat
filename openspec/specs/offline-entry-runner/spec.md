# offline-entry-runner Specification

## Purpose
An offline luajit runner loads an addon under the fake client with API mocks, calls entry points the addon registered, and fires fake events. It reads its own spec file, not a plan, and never runs code from the spec.

## Requirements

### Requirement: Offline runner calls registered entries
The runner SHALL load an addon's TOC files under the fake client and call only entries the addon registered through the stub `CheckThat.Entry`, with literal arguments from a spec file. A call to an unregistered name SHALL fail the step.

#### Scenario: Entry returns the expected values
- **WHEN** a step calls a registered entry with literal arguments and expects returns
- **THEN** the step passes only when the returned values equal the expected values

#### Scenario: Entry is expected to throw
- **WHEN** a step expects a throw and the entry raises an error containing the text
- **THEN** the step passes, and it fails when the entry returns normally

### Requirement: Mocks are data and are reported
The runner SHALL set API mocks from the spec before the addon loads, restore the earlier values when the run ends, count each mock's calls, and mark every step result that ran with a mock.

#### Scenario: Mock reaches a captured local
- **WHEN** the addon captured a global in a file-scope local and the mock was set before load
- **THEN** the entry that reads the captured local returns the mocked value

#### Scenario: Late mock misses a captured local
- **WHEN** `mockAfterLoad` sets the mock after load
- **THEN** the captured local still returns the original value and a call-time lookup returns the mocked value

### Requirement: Fake events reach the addon's handlers
The runner SHALL fire a named event with literal arguments at each frame that registered it and has an `OnEvent` script.

#### Scenario: Handler changes addon state
- **WHEN** a step fires a registered event
- **THEN** a later entry call sees the state the handler set

### Requirement: Offline command runs a plan's block
`ct.py offline <plan>` SHALL run the plan's offline block in the runner, resolving `toc` inside the folder given by `--addons` (default: the folder above the CheckThat checkout) and refusing a `toc` that leaves it. It SHALL print JUnit with one case for each step, exit 1 when a step fails, and exit 2 when the plan has no block, is not valid or the run cannot start.

#### Scenario: Wrong return
- **WHEN** a call step expects a value the entry does not return
- **THEN** that case fails and the exit code is 1

#### Scenario: Matching plan
- **WHEN** every step matches
- **THEN** the exit code is 0

#### Scenario: No block
- **WHEN** the plan has no offline block
- **THEN** the command exits 2 and says so

### Requirement: Only listed APIs can be mocked
The runner SHALL hold a closed list of mockable API names. A mock for a name not on the list SHALL stop the run before the addon loads and fail with the name. A plan cannot add to the list.

#### Scenario: Unlisted mock
- **WHEN** a plan mocks `loadstring`
- **THEN** the run fails before any addon file loads and nothing is replaced

### Requirement: Runner follows XML files the TOC lists
The runner SHALL load an XML file named on a TOC line by loading each `Script` and `Include` file it names, in order, with paths relative to that XML file, and with the addon's own name and namespace as for a TOC line. XML comments SHALL be ignored. A `file` path that leaves the addon folder SHALL stop the run before any addon file loads and name the path.

#### Scenario: Libraries load through embeds.xml
- **WHEN** a TOC lists `embeds.xml`, which names a library file and includes a second XML file that names another
- **THEN** both library files load before the next TOC line, and an entry that uses them returns the expected values

#### Scenario: XML path leaves the addon folder
- **WHEN** an XML file the TOC lists names a file with `..` or an absolute path
- **THEN** the run fails with that path and no addon file has run

#### Scenario: Commented-out file
- **WHEN** an XML file holds a `Script` line inside an XML comment
- **THEN** that file does not load

### Requirement: Offline command checks covers against the addon's specs
`ct.py offline` SHALL validate the plan with the addon's spec requirements, as `validate` does, from `--specs` or from the `openspec/specs` folder found above the plan file.

#### Scenario: Plan with covers and a specs folder
- **WHEN** a plan whose steps carry `covers:` names requirements that exist in the specs folder given by `--specs`
- **THEN** the offline block runs

#### Scenario: Plan with covers and no specs folder
- **WHEN** a plan carries `covers:` and no specs folder is given or found
- **THEN** the command exits 2 and says that covers needs the specs folder

### Requirement: Runner answers by the plan's offline level
The offline block MAY declare `level`, 1, 2, 3 or 4. A block without `level` SHALL run at level 1, so its results do not change: `GetBuildInfo` returns interface 11507 and `issecurevariable` returns false for every name. At level 2 and above the runner SHALL make `GetBuildInfo` return, as its interface number, the number on the TOC's `## Interface:` line, and the key SHALL count only at the start of a line, so the same text inside another line, such as `## Notes:`, is ignored. When the line lists several numbers, the first one SHALL be used. At level 2 and above `issecurevariable` SHALL return true for each global the fake client set up before addon code ran, and false with "Addon" for any other global. Level 3 SHALL add the game's load order (see "Level 3 loads the addon as the game does"), and level 4 the event list and the clock (see "Level 4 checks events against the client" and "Level 4 runs timers on a virtual clock"). Any other `level`, a `reload` step, `groups` or `savedVariables` below level 3, and a `wait` step below level 4, SHALL fail the load step and no addon file SHALL run. The JSON result SHALL carry the level and the interface the addon read. `ct.py offline` SHALL print a warning to stderr when the block has no `level`.

#### Scenario: Era and Forever interfaces at level 2
- **WHEN** a block with `level: 2` names a TOC that says `## Interface: 11509`, and another names one that says `## Interface: 16001`
- **THEN** the addon reads 11509 in the first run and 16001 in the second, and the JSON result carries that number

#### Scenario: Block without a level
- **WHEN** a block has no `level`
- **THEN** the addon reads interface 11507, `issecurevariable("CreateFrame")` is false, and `ct.py offline` prints the level warning

#### Scenario: Unknown level
- **WHEN** a block says `level: 5`
- **THEN** the load step fails with "offline level 5 is not supported" and no addon file runs

#### Scenario: Reload below level 3
- **WHEN** a block at level 2 holds a `reload` step
- **THEN** the load step fails and no addon file runs

#### Scenario: Level 2 sends no login events
- **WHEN** a block at level 2 fires ADDON_LOADED in an `event` step
- **THEN** the handler runs once, and `IsLoggedIn()` is true during load

#### Scenario: Wait below level 4
- **WHEN** a block at level 3 holds a `wait` step
- **THEN** the load step fails with "a wait step needs offline level 4" and no addon file runs

### Requirement: Runner scans addon files for Lua 5.1 differences
Before any addon file runs, the runner SHALL scan every file the TOC loads, XML and libraries included, with `tools/lua51_check.lua`. A finding SHALL fail the load step with the text `file:line: message` and no addon file SHALL run. The scanner SHALL report `goto` used as a statement, `::name::` labels, the `\x`, `\z` and `\u{` escapes in short strings and, for the whole numeral, the `LL`, `ULL` and `i` number suffixes, hex numbers with a fraction or `p` exponent, `0b` binary numbers and `_` inside a number, and a `[[` nested inside a level-0 long string or comment, each with its own message. It SHALL count `\r\n`, `\n\r` and a lone `\r` as one line end, so a `--` comment ends at any of them. It SHALL skip comments and long strings, and SHALL accept `goto` used as a name, including after `=`, `,`, `(`, `return` or an operator.

#### Scenario: A file uses goto
- **WHEN** an addon file holds a `goto` statement
- **THEN** the load step fails with the file, the line and a message that Lua 5.1 rejects goto

#### Scenario: goto as a name
- **WHEN** a file holds `local goto = 1`
- **THEN** the scan reports nothing

#### Scenario: goto name before a call
- **WHEN** a file holds `local x = goto` and `foo()` on the next line
- **THEN** the scan reports nothing

#### Scenario: Nested long bracket
- **WHEN** a `[[ ]]` string or comment holds another `[[`
- **THEN** the scan reports that Lua 5.1 rejects the nesting, and `[=[ ]=]` is not reported

#### Scenario: Comments and long strings
- **WHEN** `goto`, a label or an escape appears only in a comment or a long string
- **THEN** the scan reports nothing

### Requirement: Runner hides globals the game does not give addons
While addon files and steps run, the runner SHALL remove `io`, `os`, `jit`, `ffi`, `require`, `package`, `loadfile` and `dofile` from the global table and SHALL put them back when the run ends, also when a step throws outside the entry's own error handling. Such a throw SHALL fail the run with the error text.

#### Scenario: Guard and call
- **WHEN** addon code tests `io` as a guard and another entry calls `io.open`
- **THEN** the guard sees nil, the call fails with Lua's own message, and `io` is available again after the run

### Requirement: Runner reports globals the addon read as nil
The runner SHALL record the global names that code in the addon folder, outside any `Libs` or `Libraries` folder (any letter case), read as nil, and SHALL put the sorted list and the interface in its JSON result.

#### Scenario: Nil read in addon code
- **WHEN** an entry reads a global that the fake client lacks
- **THEN** `nilReads` holds that name

#### Scenario: Nil read in a library
- **WHEN** a file in `Libs` reads a missing global
- **THEN** `nilReads` does not hold that name

### Requirement: Offline command prints the nil-read report
After its summary, `ct.py offline` SHALL print the report of nil reads to stderr and put the same text in suite-level JUnit `<system-out>`, with `interface` and, when known, `build` in `<properties>`. It SHALL read census manifests from `tests/manifests/*.json`. Manifests SHALL be filtered by the run's interface first; `--build` then picks among those, and a `--build` that matches none exits 2 with a message. The report SHALL return the selected build even when no name was read as nil. With one manifest for the interface, or one picked with `--build`, it SHALL list the names present in that census, the names that addon code had set in that census session (`insecure`), and the names absent from it. With no manifest it SHALL list the names sorted. With several builds for the interface and no `--build`, it SHALL print "Interface N matches multiple builds. Showing unclassified names." and list the names unclassified. The report SHALL NOT change counts or exit codes.

#### Scenario: No manifest
- **WHEN** no manifest matches the interface
- **THEN** one sorted list of names is printed

#### Scenario: One manifest
- **WHEN** one manifest has the run's interface
- **THEN** the names are split into present and absent for its build, and JUnit properties name the build

#### Scenario: Several builds
- **WHEN** two manifests have the run's interface and `--build` is not given
- **THEN** the multiple-builds message is printed and `--build` with one of them selects it

### Requirement: Make check scans CheckThat for Lua 5.1 differences and banned globals
`make check` SHALL run the scanner over every file the CheckThat TOC files load, libraries included, and SHALL fail when CheckThat code outside `Libs` reads `io`, `os`, `jit`, `ffi`, `require`, `package`, `loadfile` or `dofile` as a global.

#### Scenario: Banned global in addon code
- **WHEN** a CheckThat file reads `io` as a global
- **THEN** `make check` fails and names the file and the global

### Requirement: Level 3 loads the addon as the game does
At level 3 the runner SHALL read the names on the TOC's `## SavedVariables` and `## SavedVariablesPerCharacter` lines and set each to nil before the files run. After the last file it SHALL assign each name that `savedVariables` holds, and leave the others as the files set them. With `## LoadSavedVariablesFirst: 1` it SHALL assign them before the first file. A `savedVariables` name the TOC does not declare SHALL fail the load step. It SHALL then fire ADDON_LOADED with the addon's folder name and whether the folder holds `Bindings.xml`, PLAYER_LOGIN, and PLAYER_ENTERING_WORLD with `true, false`, at each frame that registered the event. An event that no frame registered SHALL NOT fail the run. A handler that throws SHALL fail the load step with the event's name. `IsLoggedIn()` SHALL return false until PLAYER_LOGIN fires.

#### Scenario: File-scope write is lost
- **WHEN** an addon sets its saved variable at file scope and `savedVariables` holds a value for it
- **THEN** an entry called after load returns the saved value, not the file-scope value

#### Scenario: First login keeps the default
- **WHEN** `savedVariables` holds no value for a declared name
- **THEN** the value the file set is kept

#### Scenario: Login order
- **WHEN** an addon records the events it receives and `IsLoggedIn()` at each
- **THEN** it saw ADDON_LOADED with its folder name and `false` (no `Bindings.xml`) and `IsLoggedIn()` false, then PLAYER_LOGIN, then PLAYER_ENTERING_WORLD with `true, false`

### Requirement: Reload step loads the addon fresh
A `reload` step SHALL fire PLAYER_LEAVING_WORLD, PLAYER_LOGOUT and ADDONS_UNLOADING with `false` (the client is not closing), then copy each declared saved variable as the game saves it: strings, numbers, booleans and tables with string, number or boolean keys, without functions, userdata, threads or metatables. Two references to one table SHALL come back as two tables, and a reference to a table that holds it SHALL be dropped. A nil name SHALL not be written. The runner SHALL then load the addon fresh: globals the addon set, its frames, its registered entries and its upvalues SHALL be gone. It SHALL assign the copies and fire the login events with PLAYER_ENTERING_WORLD `false, true`. Mocks SHALL be set again, and their counts SHALL go on.

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

### Requirement: Level 4 checks events against the client
At level 4 the runner SHALL read the event list of the client the TOC's interface names: `tools/events/era.json` below 16000 and `tools/events/forever.json` from 16000. A missing list SHALL fail the load step. `RegisterEvent` and `RegisterUnitEvent` SHALL raise `Frame:RegisterEvent(): Attempt to register unknown event "NAME"` for an event the list lacks. Before any addon file runs, an `event` step SHALL fail the load step when the list lacks its event, or when the event is documented and the step gives more values than the event carries or fewer than it always carries. Below level 4 any event name SHALL register and fire.

#### Scenario: Unknown event registered
- **WHEN** addon code at level 4 registers `NOT_AN_EVENT`
- **THEN** the call raises the unknown-event error, and registering `MERCHANT_SHOW` works

#### Scenario: Unknown event step
- **WHEN** a level 4 block fires `NOT_AN_EVENT`
- **THEN** the load step fails with "the client has no event NOT_AN_EVENT" and no addon file runs

#### Scenario: Missing value
- **WHEN** a level 4 block fires `BAG_UPDATE` with no values
- **THEN** the load step fails and names the event, the values it carries and the values the step gives

### Requirement: Level 4 runs timers on a virtual clock
At level 4 `GetTime` SHALL start at 1 and `time()` at a fixed epoch, and both SHALL follow a virtual clock. A `wait` step SHALL move the clock on by its seconds and run each `C_Timer.After`, `C_Timer.NewTimer` and `C_Timer.NewTicker` callback that comes due, in order of due time and then of creation, with the clock at each callback's due time. A callback a timer makes SHALL run in the same wait when it comes due. `NewTimer` and `NewTicker` SHALL return a handle with `Cancel` and `IsCancelled` and pass it to the callback, and a ticker SHALL stop after its iterations. A callback that throws SHALL fail the wait step with the error after the other callbacks ran. The clock SHALL go on across a reload, its timers SHALL not, and each group SHALL start at 1. Below level 4 `GetTime` SHALL stay 1 and timers SHALL only queue.

#### Scenario: Timer fires on time
- **WHEN** an entry schedules `C_Timer.After(2, fn)` and the block waits 1.5 seconds, then 0.5 seconds more
- **THEN** `fn` has not run after the first wait and has run with `GetTime()` 3 after the second

#### Scenario: Ticker and cancel
- **WHEN** a ticker of 1 second with 3 iterations and a cancelled timer are made, and the block waits 10 seconds
- **THEN** the ticker ran 3 times and the cancelled timer never ran

#### Scenario: Reload
- **WHEN** a timer is pending and the block waits 2 seconds, then reloads
- **THEN** `GetTime()` is 3 after the reload and the timer never runs
