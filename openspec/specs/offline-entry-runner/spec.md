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

### Requirement: Runner answers with the interface from the TOC
The runner SHALL make `GetBuildInfo` return, as its interface number, the number on the TOC's `## Interface:` line. The key SHALL count only at the start of a line, so the same text inside another line, such as `## Notes:`, is ignored. When the line lists several numbers, the first one SHALL be used.

#### Scenario: Era and Forever interfaces
- **WHEN** a TOC says `## Interface: 11509` and another says `## Interface: 16001`
- **THEN** the addon reads 11509 in the first run and 16001 in the second, and the JSON result carries that number

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
