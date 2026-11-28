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
The runner SHALL set API mocks from the spec before the addon loads, restore the earlier values when the run ends, count each mock's calls, and mark every step result that ran with a mock. A mock's `args` and `returns` MAY hold tables (JSON objects and lists). A table argument SHALL match by value, and each call SHALL return its own copy of a table return.

#### Scenario: Mock reaches a captured local
- **WHEN** the addon captured a global in a file-scope local and the mock was set before load
- **THEN** the entry that reads the captured local returns the mocked value

#### Scenario: Late mock misses a captured local
- **WHEN** `mockAfterLoad` sets the mock after load
- **THEN** the captured local still returns the original value and a call-time lookup returns the mocked value

#### Scenario: Table return
- **WHEN** a mock of `C_MerchantFrame.GetItemInfo` returns an object, and the addon changes the table it got
- **THEN** the next call returns the object as the mock wrote it

#### Scenario: Table argument
- **WHEN** a mock of `C_AuctionHouse.GetItemSearchResultInfo` lists an itemKey object as its first argument
- **THEN** a call with an equal itemKey gets the mocked return and a call with another itemKey gets nothing

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

### Requirement: Runner reads the addon's own recordings
At level 5 a block MAY name a `recordings` folder. The runner SHALL read `<folder>/<client>.json` for the client the TOC names, beside `tools/recordings/<client>.json`. A label in both SHALL take the addon's entry. A missing file in the folder SHALL add nothing. A file that cannot be read, or has a format other than 1, SHALL fail the load step with its path. A `recording` mock that matches neither file SHALL fail with both paths.

#### Scenario: A recording from the addon
- **WHEN** a level 5 block names a folder whose `era.json` records `GetSpellInfo(133)`, and mocks `GetSpellInfo` with `recording: GetSpellInfo(133)`
- **THEN** the mock answers the recorded values

#### Scenario: The addon's entry wins
- **WHEN** the addon's file and the bundled file both record `GetItemInfo(6948)` with different names
- **THEN** the mock answers the addon's name

### Requirement: Hook steps run the developer's Lua
At level 5 a block MAY name a `hooks` file. The runner SHALL load it once, after the other load checks pass and before the addon loads, and it SHALL return a table of functions. A `{ hook: name }` step SHALL call `hooks[name](ctx, ...)` with the step's `args`, and SHALL judge `returns` and `throws` as for a `call` step; with neither, a hook that returns passes and a hook that raises fails with the error text. A missing file, a file that raises or returns no table, a step naming a function the table lacks, or a hook step without a hooks file SHALL fail the load step before any addon file runs. While a hook runs, every global hidden from addon code SHALL hold the host's value, `require`, `dofile` and `loadfile` included; addon code run through `ctx.fire` or `ctx.advance` SHALL see the hidden names as addon code does, and the addon's own values of those names SHALL be kept across a hook. A global the hooks file reads as nil SHALL NOT be in the nil-read report.

#### Scenario: A hook reads the addon's namespace
- **WHEN** a hook returns `ctx.ns.count` after an event step, and the step expects `returns: [1]`
- **THEN** the step passes when the addon's handler set `ns.count` to 1

#### Scenario: A hook that raises
- **WHEN** a hook calls `ctx.eq(2, 3, "rows")`
- **THEN** the step fails with "rows: expected 3, got 2"

#### Scenario: A missing hook
- **WHEN** a step names `setup` and the hooks file has no `setup`
- **THEN** the load step fails with "hook setup is not in" and the file's path, and no addon file runs

### Requirement: The hook context is a public API
Each hook SHALL get a `ctx` with `ns` (the addon's private namespace of the current load), `client` (`era` or `forever`), `level`, `fire(event, ...)` (returns the number of frames, raises when a handler raises or when the event fails the level 4 event check), `combat(on)` (enters or leaves combat as the fake client models it), `advance(seconds)` (moves the virtual clock and runs the timers due, raises when one raises), `mockCalls(api)` (the count for this group), `eq(got, want, what)` and `same(got, want, what)` (deep, cycle-safe, naming the first differing path), `ok(value, what)` (raises when value is false or nil), `raises(fn, text, what)` (raises unless fn raises an error that contains the plain text) and `reload()` (the game's reload as a `reload` step does it, called from the hook or test itself and not from a handler it fires; `ctx.ns` then names the new load's namespace; raises with the step's error text when it fails). A `ct test` test SHALL get the same `ctx`. Fields SHALL only be added, never removed or changed in meaning.

#### Scenario: Combat and the clock from a hook
- **WHEN** a hook calls `ctx.combat(true)`, then `ctx.advance(2)`
- **THEN** `InCombatLockdown()` is true in the addon's timer callback that comes due

#### Scenario: A reload from a test
- **WHEN** a test sets a saved variable through the addon, then calls `ctx.reload()`
- **THEN** the addon's new load reads the value, and `ctx.ns` is the new namespace

### Requirement: ct test runs the developer's own tests
`ct test [folder]` SHALL run each `<folder>/tests/test_*.lua`, in name order, once for each client the folder has a TOC for, each file and client in its own process, at the runner's newest level. The client of a TOC SHALL come from its `## Interface:` numbers (10000 to 15999 Era, 16000 to 19999 Forever, any other left out), and each client SHALL run with its own number. When two TOCs claim a client, the suffix that client reads (`_Vanilla` or `_Classic`, `_Camelot`) SHALL win, then any other suffix, then the plain name, then the first by name. The addon's name SHALL be the folder's when a TOC is named after it, else the name the TOC files share. Each process SHALL write its result apart from what the test file writes, which the command SHALL show under the file's lines; a process that runs longer than 300 seconds SHALL be stopped and fail. Nil reads of any file in the addon's `tests/` folder SHALL NOT be in the report, and `require` SHALL find files there. A test file SHALL get `ct` as its `...`, with `ct.test(name, [options,] fn)` and `ct.API` (1). Each test SHALL get a fresh load of the addon with `options.mocks` and `options.savedVariables` (the offline block's shapes) and SHALL call `fn(ctx)` with the hook context; it passes when `fn` returns and fails with the error text when it raises or the load fails. The command SHALL print one line for each test and client, the nil-read report for each client, and a summary, and SHALL exit 1 when a test fails and 2 when the folder has no TOC, no test file, or no test matches `--name`. `--client` SHALL narrow the run to one client and fail when the folder has no TOC for it. `--tests DIR` SHALL run each `DIR/test_*.lua` in place of `<folder>/tests/test_*.lua`, `require` SHALL find files in `DIR`, and the command SHALL exit 2 when `DIR` is not a folder or holds no `test_*.lua`.

#### Scenario: Both clients
- **WHEN** a folder has `MyAddon_Vanilla.toc` (11507) and `MyAddon_Camelot.toc` (16001) and one test
- **THEN** `ct test` runs the test twice, once with each TOC, and prints a line for `era` and one for `forever`

#### Scenario: A failing test
- **WHEN** a test calls `ctx.eq(ctx.ns.count, 2, "count")` and the addon set 1
- **THEN** its line says FAIL with "count: expected 2, got 1" and the command exits 1

#### Scenario: A file that raises at load
- **WHEN** a test file raises before it registers a test
- **THEN** the file fails for that client with the error text, and the other files still run

#### Scenario: Tests outside the addon folder
- **WHEN** a repo keeps `MyAddon/` and its tests in `tests/ct/test_bags.lua`, and runs `ct test MyAddon --tests tests/ct`
- **THEN** `ct test` runs `test_bags.lua` and not `MyAddon/tests/test_*.lua`, and a `--tests` folder that is missing or has no `test_*.lua` exits 2