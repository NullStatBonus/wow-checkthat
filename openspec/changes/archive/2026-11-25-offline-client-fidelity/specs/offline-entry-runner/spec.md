# Spec Delta

## ADDED Requirements

### Requirement: Runner answers with the interface from the TOC
The runner SHALL make `GetBuildInfo` return, as its interface number, the number on the TOC's `## Interface:` line. When the line lists several numbers, the first one SHALL be used.

#### Scenario: Era and Forever interfaces
- **WHEN** a TOC says `## Interface: 11509` and another says `## Interface: 16001`
- **THEN** the addon reads 11509 in the first run and 16001 in the second, and the JSON result carries that number

### Requirement: Runner scans addon files for Lua 5.1 differences
Before any addon file runs, the runner SHALL scan every file the TOC loads, XML and libraries included, with `tools/lua51_check.lua`. A finding SHALL fail the load step with the text `file:line: message` and no addon file SHALL run. The scanner SHALL report `goto` used as a statement, `::name::` labels, the `\x`, `\z` and `\u{` escapes in short strings and the `LL`, `ULL` and `i` number suffixes, and a `[[` nested inside a level-0 long string or comment, each with its own message. It SHALL skip comments and long strings, and SHALL accept `goto` used as a name, including after `=`, `,`, `(`, `return` or an operator.

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
After its summary, `ct.py offline` SHALL print the report of nil reads to stderr and put the same text in suite-level JUnit `<system-out>`, with `interface` and, when known, `build` in `<properties>`. It SHALL read census manifests from `tests/manifests/*.json`. With one manifest for the interface, or one picked with `--build`, it SHALL list the names present in that census, the names that addon code had set in that census session (`insecure`), and the names absent from it. With no manifest it SHALL list the names sorted. With several builds for the interface and no `--build`, it SHALL print "Interface N matches multiple builds. Showing unclassified names." and list the names unclassified. The report SHALL NOT change counts or exit codes.

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
