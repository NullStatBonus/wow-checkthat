# test-plan-format Specification

## Purpose
Deterministic, schema-validated format for in-game test plans, so the runner and tools read steps the same way.

## Requirements

### Requirement: Plans are authored as schema-validated YAML
A plan SHALL be one YAML file per addon validated by the published JSON Schema (`schema/test-plan.schema.json`). Unknown fields, duplicate step IDs, and unresolved references SHALL fail validation, in the compiler and again in the addon on import.

#### Scenario: Unknown field rejected
- **WHEN** a step contains a field not in the schema
- **THEN** validation fails and names the step ID and field

#### Scenario: Duplicate ID rejected
- **WHEN** two steps share an `id`
- **THEN** validation fails

### Requirement: Steps have a fixed deterministic shape
Each step SHALL have a stable `id` independent of numbering, `title`, `action`, `expect` in player-visible words, and `verify` modes; and MAY have `clients`, `requires`, `setup`, `assertions`, `reviewer`, `cleanup`, `reload`, `notes`, `async`. `action.text` SHALL be a string or a list of two to six strings, one player action each. `expect` SHALL be a string or a list of two to six strings, one result each. Sections group steps and MAY add shared `requires`, `setup` and `clients`, which compilation SHALL merge into every member step. A plan MAY carry a once-per-run `preamble` and a `handoff`.

#### Scenario: Section prerequisites inherited
- **WHEN** a section declares a requirement
- **THEN** every step in it lists that requirement after compilation

#### Scenario: Actions as a list
- **WHEN** a step's `action.text` lists three actions
- **THEN** validation accepts it and the compiled step keeps the list

#### Scenario: One-item list
- **WHEN** `action.text` or `expect` is a list of one string
- **THEN** validation fails and says to write a string

#### Scenario: Markdown in a list item
- **WHEN** a list item uses backticks
- **THEN** validation fails as for a string

### Requirement: Actions are a closed set of kinds
`action.kind` SHALL be one of `manual`, `copy-slash`, `secure-macro`, `reload`, `wait-event`. An action MAY list `commands` offered as copy text. Every slash command, copy text and macro body SHALL be limited to the commands of the plan's addon plus `/reload` and `/console scriptErrors 0|1`. The commands of an addon are the runner-shipped list for an addon the runner knows, the prefixes the addon declared through `CheckThat.Commands`, and the prefixes in the plan's `commands`. A plan SHALL NOT add `/run`, `/script`, `/dump`, `/console`, the game's debug commands, or a command of another addon the runner knows. No kind SHALL cause game input without a user keypress or click. A `wait-event` action SHALL be valid only on an auto step.

#### Scenario: Unknown action kind
- **WHEN** a step uses `kind: cast`
- **THEN** validation fails

#### Scenario: Plan tries to allow its own commands
- **WHEN** a plan macro contains `/run`, `/script`, `/cast`, or another addon's slash command, or the plan lists `/run` or another known addon's command in `commands`
- **THEN** validation fails, in the compiler and on import

#### Scenario: Wait-event without auto
- **WHEN** a step uses `kind: wait-event` and is not an auto step
- **THEN** validation fails

### Requirement: Assertions and probes are typed
Assertions SHALL be `log` (named log source, one of equals, contains, pattern, with scope attempt, run or session, optional absent), `log-sequence` (ordered matchers, and an item after the first MAY give `within`), or `state` (probe from a closed registry: addon-loaded, global-value, frame-shown, money, bag-free-slots, item-count, frame-text; operator; value). A `state` assertion MAY give `name` (an addon, a global or a frame), `path` (a dotted field of a table global), `id` (the item of `item-count`, a number) and `bag` (the one bag of `bag-free-slots`, a whole number). Scope `attempt` reads the lines written after the step's attempt opened, `run` the lines written after the current run started (across `/reload`), and `session` the whole retained log. Any assertion MAY be `diagnostic`, recorded but never gating. `verify` SHALL be a set of `player`, `assertions`, `reviewer`; `assertions` requires assertions to exist and vice versa; `reviewer` requires reviewer text kept verbatim.

#### Scenario: Unknown probe
- **WHEN** an assertion names a probe absent from the registry
- **THEN** validation fails

#### Scenario: Ordered evidence
- **WHEN** a step needs "off" logged before "on"
- **THEN** a `log-sequence` passes only if the lines appear in that order inside the attempt window

#### Scenario: Run scope accepted
- **WHEN** a log assertion sets `scope: run`
- **THEN** `ct validate` and plan import accept it

#### Scenario: Unknown scope
- **WHEN** an assertion sets `scope: forever`
- **THEN** validation fails with "bad scope"

### Requirement: A sequence item may name a gap

An item of a `log-sequence` after the first MAY give `within`: the whole number of seconds, 1 to 600, within which its line SHALL be written after the line matched by the item before it. `ct validate`, `ct compile` and plan import SHALL refuse `within` on the first item, a `within` that is not a whole number, and a value below 1 or above 600. The check SHALL read the time of every line of its window; a source that keeps no time for its lines, and a window with a line whose time cannot be read, SHALL leave the check unverified with "this log keeps no time for these lines, so a within check cannot be judged". When the lines appear in order but a gap is longer than its `within`, the check SHALL be unverified with "sequence stopped at item N", where N is the item whose line it could not place, and never failed. An earlier line of an item that leaves too little time SHALL NOT fail a check that a later line of the same item satisfies. A plan that gives `within` SHALL need plan revision 3: `ct compile` SHALL write `needs: 3`, and a reader of revision 2 SHALL refuse the plan with "needs a newer CheckThat".

#### Scenario: Two lines in time
- **WHEN** a sequence's second item gives `within: 2` and its line is written 2 seconds after the first item's line
- **THEN** the check passes

#### Scenario: A line too late
- **WHEN** the second line is written 3 seconds after the first
- **THEN** the check is unverified with "sequence stopped at item 2"

#### Scenario: A log with no times
- **WHEN** the source's lines carry no time
- **THEN** the check is unverified and never passes

#### Scenario: The first item
- **WHEN** the first item of a sequence gives `within`
- **THEN** validation fails

### Requirement: The game state probes are read-only and never guess
`money` SHALL read `GetMoney()`, the balance in copper. `bag-free-slots` SHALL read `C_Container.GetContainerNumFreeSlots`, or the older global `GetContainerNumFreeSlots`, summed over bags 0 to 4, or for the one `bag` the assertion names. `item-count` SHALL read `C_Item.GetItemCount`, or the older global `GetItemCount`, for the item `id` names. `frame-text` SHALL read a named frame's `GetText` and cut it to 80 characters. A probe SHALL answer nil for a missing function, a raising call and a value the game hides (`issecretvalue`); `frame-text` SHALL also answer nil for a value that is not text, and a `bag-free-slots` sum SHALL be nil when one bag cannot be read. No probe SHALL be protected, change any state, or write anything. `ct validate`, plan import and the schema SHALL refuse `item-count` without a numeric `id`, an `id` that is not a number, and a `bag` that is not a whole number. The `money`, `bag-free-slots`, `item-count` and `frame-text` probes are plan revision 3: `ct compile` SHALL write `needs: 3` for a plan with a state check that names one.

#### Scenario: Money
- **WHEN** a state assertion names `money` with `op: ge` and `value: 100`
- **THEN** the check passes with at least 100 copper, and is unverified when the game cannot say

#### Scenario: One bag unknown
- **WHEN** one of bags 0 to 4 cannot be read
- **THEN** a `bag-free-slots` sum is unverified, never a smaller number

#### Scenario: Item without an id
- **WHEN** a state assertion names `item-count` and gives no numeric `id`
- **THEN** validation fails

#### Scenario: Frame text
- **WHEN** a state assertion names `frame-text` for a frame that says `Bank`, with `op: eq` and `value: Bank`
- **THEN** the check passes, and a missing or empty frame leaves it unverified

#### Scenario: A new probe needs revision 3
- **WHEN** a plan whose only addition is a `money` state check is compiled, and another plan checks only `addon-loaded`
- **THEN** the first compiles with `needs: 3`, so CheckThat 1.0.0 says it needs a newer CheckThat, and the second compiles with no `needs`

### Requirement: Existing plans map without loss
Each legacy checklist item SHALL map to one step whose `expect` is its `Check:` text. `Log: none` SHALL map to `verify: [player]`. Any other `Log:` text SHALL be kept verbatim as `reviewer`, and literal log lines SHALL become diagnostic assertions until a human promotes them. The plan's preamble prose SHALL map to `preamble`.

#### Scenario: Log none
- **WHEN** a legacy item says `Log: none; on screen only`
- **THEN** the step has no assertions and verify is `[player]`

#### Scenario: Log with literals
- **WHEN** a legacy item names `[kt] started` in its Log line
- **THEN** the step keeps the full Log text as reviewer text and gains a diagnostic contains assertion

### Requirement: Steps may request a screenshot
A step MAY set `screenshot: true`. It SHALL be a boolean; any other value fails validation.

#### Scenario: Flag accepted
- **WHEN** a step sets `screenshot: true`
- **THEN** the plan validates and the card asks for Print Screen

### Requirement: Only unconditional log checks may be required
A converted check SHALL be a required assertion only when its log line is emitted on every correct run of the step and was confirmed in the addon source or a saved log. A line that depends on a race, an optional addon, a character, or an event order SHALL stay diagnostic or reviewer-only. Steps that apply to one client SHALL list that client.

#### Scenario: Conditional line
- **WHEN** a log line appears only if the game reports a move after a window closes
- **THEN** the step keeps it diagnostic

#### Scenario: Client-specific step
- **WHEN** a step is for Classic Era only
- **THEN** it lists `classic-era` and is inapplicable on Forever

### Requirement: The runner has a self-test plan
The project SHALL ship a plan for the runner itself that exercises each action kind and an evidence assertion, runnable without any sibling addon.

#### Scenario: Self-test validates
- **WHEN** the self-test plan is compiled
- **THEN** it validates and decodes in the addon

### Requirement: Steps and sections may request a share point
A step MAY set `share` to `none`, `reload` or `export`; a section MAY set it, and compilation SHALL apply it to the section's last step. Any other value fails validation.

#### Scenario: Section share
- **WHEN** a section sets `share: export`
- **THEN** its last step carries `share: export` after compilation

### Requirement: Display text uses native formatting
Text a player sees (preamble, handoff, section and step titles, setup, action text, expect, intro, notes) SHALL use the game's own formatting: color codes such as |cffffd100text|r for emphasis. It SHALL NOT use Markdown. Validation SHALL reject backticks and double asterisks in those fields, in the compiler and on import. Titles and section names SHALL be plain text. A literal pipe SHALL be written as two pipes.

#### Scenario: Markdown rejected
- **WHEN** a step's action text contains a backtick or double asterisks
- **THEN** validation fails and names the field

#### Scenario: Converter output
- **WHEN** a legacy item contains bold text and a code span
- **THEN** the converted step uses a gold color code for the bold text and a light blue color code for the code span

### Requirement: Assertions may carry a label
An assertion MAY set `label`, a player-readable name for the check, in native formatting. The card SHALL show it in the live checks and, without one, SHALL show a generic description.

#### Scenario: Labelled check
- **WHEN** an assertion sets `label: Hooks started`
- **THEN** the card lists "Hooks started" among the live checks

### Requirement: Validation warns about unlisted slash commands
Validation SHALL warn, naming the step ID and command, when step action text names a slash command from the plan's allow list and the step's `commands` does not list it. Color codes in the text SHALL NOT hide the command. Warnings SHALL NOT fail validation or change its exit status.

#### Scenario: Colored command not listed
- **WHEN** a step's text contains a color-coded allowed slash command and `commands` is empty
- **THEN** validation prints a warning with the step ID and the command, and still succeeds

#### Scenario: Plain command not listed
- **WHEN** a step's text names an allowed slash command without color codes and `commands` lacks it
- **THEN** validation prints the same warning

#### Scenario: Command listed
- **WHEN** the step's `commands` lists the named command
- **THEN** validation prints no warning for it

#### Scenario: Copy-slash step
- **WHEN** a step's action is `copy-slash`, whose text is the command itself
- **THEN** validation prints no warning for it

#### Scenario: Command outside the allow list
- **WHEN** step text names a slash command not in the allow list
- **THEN** validation prints no warning for it

### Requirement: A step may be settled by its own evidence
A step MAY set `auto: true`. An auto step SHALL list `assertions` in `verify`, SHALL NOT list `player` in `verify`, and SHALL have at least one required assertion. An auto step with a required check that something did not happen SHALL set `timeout`. Validation SHALL reject an auto step that breaks any of these rules, in the compiler and on import.

#### Scenario: Auto step with a required line
- **WHEN** a step sets `auto: true`, verifies by assertions only, and has a required log assertion
- **THEN** validation passes

#### Scenario: Auto step that needs the player
- **WHEN** a step sets `auto: true` and lists `player` in `verify`
- **THEN** validation fails

#### Scenario: Auto step with only diagnostic assertions
- **WHEN** a step sets `auto: true` and every assertion is diagnostic
- **THEN** validation fails

#### Scenario: Auto step with an absence check
- **WHEN** a step sets `auto: true` and a required assertion checks that a line is absent
- **THEN** validation fails unless the step also sets `timeout`

### Requirement: An auto step may set a timeout
An auto step MAY set `timeout`, a whole number of seconds from 5 to 300. A step that is not auto SHALL NOT set `timeout`. A plan SHALL NOT supply a default timeout; a step without one waits for the player.

#### Scenario: Timeout in range
- **WHEN** an auto step sets `timeout: 30`
- **THEN** validation passes

#### Scenario: Timeout out of range
- **WHEN** an auto step sets `timeout: 3` or `timeout: 600`
- **THEN** validation fails

#### Scenario: Timeout without auto
- **WHEN** a step sets `timeout` and does not set `auto: true`
- **THEN** validation fails

### Requirement: The runner's own plans name CheckThat
A plan for the runner itself SHALL name the addon `CheckThat` and SHALL allow the slash commands `/ct` and `/checkthat` and no others.

#### Scenario: Runner plan
- **WHEN** a plan for `CheckThat` has a macro `/ct status` or `/checkthat status`
- **THEN** validation passes

#### Scenario: Another addon's command
- **WHEN** a plan for `CheckThat` has a macro `/kt debug on`
- **THEN** validation fails

### Requirement: Plans may declare categories
A plan MAY set `categories`: a list of objects with a unique `id` (lower case letters, digits, dot, dash), a `title` and an optional `intro`. A step or section MAY set `category` to a declared id. A plan that declares categories SHALL have every step resolve to one. Unknown ids SHALL fail validation, in the compiler and on import.

#### Scenario: Unknown category id
- **WHEN** a step names a category the plan does not declare
- **THEN** validation fails and names the step and the id

#### Scenario: Section default
- **WHEN** a section sets `category: bank`
- **THEN** every step in it lists `bank` after compilation unless it names its own

### Requirement: Fact assertions check typed values
An assertion MAY have `kind: fact` with `source` (a log source), `addon`, `key` and an operator `op`. Operators SHALL be `eq`, `ne`, `gt`, `ge`, `lt`, `le`, `between` (value is a list of two numbers), `approx` (with `tolerance`), `in` (value is a list), `matches`, `contains`, `type` (number, boolean or string), `exists` and `missing`. An assertion MAY set `which` to `last`, `any` or `all`; the default is `last`. A value of the wrong shape for its operator SHALL fail validation.

#### Scenario: Between needs two numbers
- **WHEN** a fact assertion uses `between` with one value
- **THEN** validation fails

#### Scenario: Unknown operator
- **WHEN** a fact assertion uses `op: near`
- **THEN** validation fails

### Requirement: Log and fact assertions may count matches
A `log` or `fact` assertion MAY set `count` with `exactly`, `min` or `max`, each a whole number from 0 to 1000. `exactly` SHALL NOT combine with `min` or `max`, and `min` SHALL NOT exceed `max`. `count` SHALL NOT combine with `absent`.

#### Scenario: Count with absent
- **WHEN** an assertion sets both `count` and `absent`
- **THEN** validation fails

#### Scenario: Called exactly twice
- **WHEN** an assertion sets `count: { exactly: 2 }`
- **THEN** the plan validates

### Requirement: A log source may be quiet
A log source MAY set `quiet: true`, meaning that no new lines is a valid result. The default SHALL stay not quiet.

#### Scenario: Error log source
- **WHEN** a plan declares a source with `quiet: true`
- **THEN** the plan validates

### Requirement: State probes accept more operators
A `state` assertion SHALL accept the existing operators and also `ge`, `le`, `between`, `approx`, `matches`, `type`, `in` and `missing`, with the value shapes of fact assertions.

#### Scenario: Range on a global
- **WHEN** a state assertion reads a global with `op: between` and `value: [1, 5]`
- **THEN** the plan validates

### Requirement: A check that something did not happen is judged at the timeout
A required assertion that is an absence check, a fact check with the operator `missing`, or a count with `exactly` or `max` SHALL be judged when an auto step's timeout ends, as more lines can arrive until then. An auto step with such an assertion SHALL set `timeout`. It SHALL settle as fail at once when the check can no longer hold.

#### Scenario: Absence check with a timeout
- **WHEN** an auto step has a required absence check and `timeout: 10`
- **THEN** validation passes, and the step records pass after 10 seconds if the line never appeared

#### Scenario: No timeout
- **WHEN** an auto step has a required count with `exactly: 2` and no `timeout`
- **THEN** validation fails and says the step needs a timeout

#### Scenario: Broken before the timeout
- **WHEN** a third matching line arrives in a step that needs exactly two
- **THEN** the step records fail at once

#### Scenario: Lower bound
- **WHEN** an auto step has a required count with only `min: 2`
- **THEN** it needs no timeout and settles as soon as two lines are in

### Requirement: A log source may declare its capacity
A log source MAY set `cap`, a whole number from 1 to 100000: how many lines the log keeps before it drops the oldest. A log that holds fewer lines than `cap` SHALL count as never rolled, so the line where a step began is certain.

#### Scenario: Alike lines under the cap
- **WHEN** a source with `cap: 100` holds three identical lines and a step needs no new line
- **THEN** the check can pass, as the step began after the third line

#### Scenario: Bad cap
- **WHEN** a source sets `cap: 0`
- **THEN** validation fails

### Requirement: The id failed is reserved
Validation, in the compiler and on import, SHALL reject the id `failed` as a category id, and as a section id when the plan declares no categories, because `/ct rerun failed` uses the name.

#### Scenario: A category called failed
- **WHEN** a plan declares a category with the id `failed`
- **THEN** validation fails and says the id is reserved

### Requirement: Validation rejects a step that judges its own result line
`ct.py validate` SHALL report an error when a step's log assertion `equals` or `contains` text that matches `[ct] step <own id> `, because CheckThat judges a result before it writes that line.

#### Scenario: Own result line asserted
- **WHEN** step `pass-me` asserts `[ct] step pass-me pass`
- **THEN** validation fails and names the step

#### Scenario: Earlier step's line asserted
- **WHEN** a later step asserts `[ct] step pass-me pass` with `scope: session`
- **THEN** validation passes

### Requirement: Validation warns when the first step has no version check
`ct.py validate` SHALL warn, without failing, when the first step of a plan has no version check.

#### Scenario: No version check first
- **WHEN** the first step has no version assertion
- **THEN** validation prints a warning and exits zero

### Requirement: Plan may carry an offline block
A plan MAY hold a top-level `offline` object with `toc`, optional `tocs` (an object with `era` and `forever` TOC paths, at least one), `mocks`, `mockAfterLoad`, `level` (1 to 6), `savedVariables`, `recordings` (the addon's recordings folder, a path inside the addons folder like `toc`) and `hooks` (the addon's Lua hooks file, a path inside the addons folder like `toc`), and either `steps` or `groups`. Each step is one of a `call` (addon, entry, literal `args`) with `returns` or `throws`, an `event` (name, literal `args`), a `mockCalls` count, a `hook` (a function name in the hooks file, with literal `args` and `returns` or `throws`), `reload: true`, `wait` (seconds, 0 to 86400), or a `tooltip` check (`lines` as a count, or `equals` or `contains` text with an optional `line`). `predicts` (optional) maps a plan step id to a non-empty list of offline step ids (`offline.N`, or `offline.G.N` in a group); validation SHALL fail an id that names no plan step or no offline step. `savedVariables` maps a global name to a literal value. A mock entry holds `args` and `returns`, or instead a `recording` (a label such as `GetItemInfo(6948)`) that takes both from a recorded call for the client the block runs on; it SHALL NOT hold `recording` with `args` or `returns`. Each group holds `steps` and optional `label`, `mocks` and `savedVariables`. `reload`, `groups` and `savedVariables` SHALL be valid only with `level` 3 or more, `wait` only with `level: 4`, and `tocs`, `recordings`, `hooks`, `tooltip` and `hook` steps and a mock `recording` only with `level: 5`. The runner SHALL pass a `tooltip` step when the lines on `GameTooltip` match and fail it with the lines it found when they do not. A `tooltip` step holds `lines`, or `equals` or `contains` (not both) with an optional `line`, and no other mix. `ct.py offline --client` reads `tocs`; without that option only `toc` runs, and a plan without `tocs` validates and runs as before. Validation SHALL reject any other shape. Compile SHALL remove the block, so the compiled string and its digest do not contain it.

#### Scenario: Valid block
- **WHEN** a plan holds an offline block with one call step
- **THEN** `ct.py validate` passes

#### Scenario: Unknown step field
- **WHEN** an offline step holds a field the schema does not list
- **THEN** `ct.py validate` fails

#### Scenario: Compile drops the block
- **WHEN** the same plan is compiled with and without the block
- **THEN** both compiled strings are equal

#### Scenario: Offline level
- **WHEN** an offline block says `level: 6`, and another says `level: 7`
- **THEN** validation passes the first and fails the second

#### Scenario: One TOC for each client
- **WHEN** a block at level 5 holds `tocs` with an `era` path, a `forever` path, or both, and another block holds `tocs` with a `retail` key or an empty object
- **THEN** validation passes the first and fails the second

#### Scenario: Offline predictions
- **WHEN** a block holds `predicts` that maps a plan step to `offline.1`, and another maps a plan step to `offline.9` in a block of two steps, or maps an unknown plan step
- **THEN** validation passes the first and fails the others

#### Scenario: Mock from a recording
- **WHEN** a level 5 block mocks `GetItemInfo` with `recording: GetItemInfo(6948)`, and another mocks it with a `recording` and `returns`, or with a `recording` at level 4
- **THEN** validation passes the first and fails the others

#### Scenario: Tooltip step
- **WHEN** a level 5 block holds a `tooltip` step with `lines: 3`, with `contains`, or with `line` and `equals`, and another holds an empty `tooltip`, `line` alone, or `lines` with `contains`
- **THEN** validation passes the first and fails the second

#### Scenario: Tooltip below level 5
- **WHEN** a block at level 4 or below, or with no level, holds a `tooltip` step, in its steps or in a group
- **THEN** validation fails

#### Scenario: Tocs below level 5
- **WHEN** a block at level 4 or below, or with no level, holds `tocs`
- **THEN** validation fails

#### Scenario: Reload below level 3
- **WHEN** a block at level 2 holds a `reload` step, `groups` or `savedVariables`
- **THEN** validation fails

#### Scenario: Wait below level 4
- **WHEN** a block at level 3 holds a `wait` step, in its steps or in a group
- **THEN** validation fails

#### Scenario: Steps and groups
- **WHEN** a block holds both `steps` and `groups`
- **THEN** validation fails

#### Scenario: The addon's recordings folder
- **WHEN** a level 5 block holds `recordings: MyAddon/recordings`, another holds it at level 4, and another holds `recordings: ../elsewhere`
- **THEN** validation passes the first and fails the second, and `ct.py offline` refuses the third because it leaves the addons folder

#### Scenario: Hook steps
- **WHEN** a level 5 block holds `hooks: MyAddon/tests/offline_hooks.lua` and a step `{ hook: rows, returns: [3] }`, another holds a `hook` step at level 4, another a `hook` step with both `returns` and `throws`, and another a `hook` step with no `hooks`
- **THEN** validation passes the first and fails the others

### Requirement: Step may call an entry
A step MAY hold `call: {addon, entry, args}` only when it is an auto step. `addon` and `entry` SHALL be names of the same form as a fact's addon and key, and `args` SHALL be a list of at most 8 strings, numbers or booleans. Validation SHALL reject any other field or shape, in the game and in the tools.

#### Scenario: Call on a manual step
- **WHEN** a step has `call` and is not auto
- **THEN** validation fails

### Requirement: Tools reject unknown fields and the game ignores them
The schema SHALL set `additionalProperties: false`, so `ct.py` rejects an unknown field. `Plan.Validate` in the game SHALL ignore a field it does not know, so a field meant only for the tools never stops an import.

#### Scenario: Tool rejects
- **WHEN** a step has a field the schema does not list
- **THEN** `ct.py validate` fails

#### Scenario: Game ignores
- **WHEN** an imported plan has an unknown field on a step or section
- **THEN** `Plan.Validate` returns no error for it

### Requirement: Steps and sections may name the requirements they cover
A step or section MAY set `covers`: a list of requirement names, each the text of a `### Requirement:` heading in the addon's `openspec/specs/*/spec.md`. The field is for the tools only. A name that matches no heading, or a plan with `covers` and no specs folder to check, SHALL fail validation. The compiler SHALL drop `covers`, so the compiled string is the same with and without it.

#### Scenario: Unknown requirement
- **WHEN** a step covers a name that no spec heading has
- **THEN** validation fails and names the step and the name

#### Scenario: Compiled string
- **WHEN** a plan adds `covers` to a step
- **THEN** the compiled string is byte-identical to the one without it

### Requirement: Validation warns about a long plan
`ct.py validate` SHALL warn, without failing, when a plan has more than 25 steps or a section has more than 10 steps, counting each case of a step with `cases` as a step. The warning SHALL name the section or the step count and suggest splitting the plan.

#### Scenario: Plan over 25 steps
- **WHEN** a plan has 26 steps
- **THEN** validation prints a warning that names 26 steps and plan sets, and exits zero

#### Scenario: At the limit
- **WHEN** a plan has 25 steps in sections of at most 10
- **THEN** validation prints no size warning

#### Scenario: Section over 10 steps
- **WHEN** a section has 11 steps
- **THEN** validation prints a warning that names the section

#### Scenario: Cases count
- **WHEN** a section has 9 steps and one of them has 2 cases
- **THEN** it counts as 10 steps and gets no warning

### Requirement: Plan may declare its purpose
A plan MAY set `purpose` to `foundation` (the release gate: the systems every feature depends on, run by one character) or `feature` (deep on one feature, run when it changes). The field is for the tools only. Any other value SHALL fail validation. The compiler SHALL drop `purpose`, so the compiled string is the same with and without it.

#### Scenario: Unknown purpose
- **WHEN** a plan sets `purpose: release`
- **THEN** `ct.py validate` fails

#### Scenario: Compiled string
- **WHEN** a plan adds `purpose: foundation`
- **THEN** the compiled string is byte-identical to the one without it

### Requirement: Validation warns about technical wording in a plan with a purpose
When a plan declares `purpose`, `ct.py validate` SHALL warn, without failing and naming the step ID, when a step's action text or `expect` names a slash command, or when its `expect` speaks of the log. Color codes SHALL NOT hide a command. A plan without `purpose` SHALL get none of these warnings.

#### Scenario: Command in action text
- **WHEN** a plan with `purpose: feature` has a step whose action text is "Enter |cff99ccff/cvn test sell|r."
- **THEN** validation prints a warning that names the step and says to keep commands behind Run, and exits zero

#### Scenario: Log in Expect
- **WHEN** a plan with a purpose has a step whose `expect` is "the addon logs the route"
- **THEN** validation prints a warning that names the step and says Expect states what is on screen

#### Scenario: Logging in is not the log
- **WHEN** a step's `expect` is "you log in without an error", or says "log out" or "log on"
- **THEN** validation prints no wording warning for it

#### Scenario: Log words
- **WHEN** a step's `expect` says "log", "logs", "logged" or "logging"
- **THEN** validation warns for it

#### Scenario: Copy-slash step
- **WHEN** a plan with a purpose has a `copy-slash` step, whose action text is the command itself
- **THEN** validation prints no command warning for its action text

#### Scenario: Plan without a purpose
- **WHEN** a plan without `purpose` has a command in its action text
- **THEN** validation prints no wording warning, as before

### Requirement: Validation warns about a long foundation plan
When a plan declares `purpose: foundation`, `ct.py validate` SHALL warn, without failing, when it has more than 12 steps, counting each case as a step. The warning SHALL suggest one step per pillar and moving the rest to a feature plan. The 25-step and 10-step warnings SHALL still apply to every plan.

#### Scenario: Foundation plan over 12 steps
- **WHEN** a plan with `purpose: foundation` has 13 steps
- **THEN** validation prints a warning that names 13 steps and feature plans, and exits zero

#### Scenario: Feature plan of 13 steps
- **WHEN** a plan with `purpose: feature` has 13 steps
- **THEN** validation prints no foundation size warning

### Requirement: Validation warns when the version step accepts an older build
When the addon's TOC is known, `ct.py validate` and `compile` SHALL read its `## Version:` and warn, without failing, when the first step's `version` fact assertion (`key: version` or `entry.version`) accepts a lower version. The fact value is `major*10000 + minor*100 + patch`. The warning SHALL name the step, the accepted version and the addon's version. The TOC is known from `--addon-src <folder>`, or else from the plan's `offline.toc` when that file exists under the addons folder.

#### Scenario: Plan behind the TOC
- **WHEN** the TOC says `## Version: 1.13.1` and the version step has `op: ge`, `value: 11300`
- **THEN** validation prints `<step>: accepts 1.13.0; the addon is 1.13.1` and exits zero

#### Scenario: Plan matches the TOC
- **WHEN** the version step has `op: ge`, `value: 11301` and the TOC says 1.13.1
- **THEN** validation prints no version warning

#### Scenario: TOC unknown
- **WHEN** there is no `--addon-src` and no `offline.toc` file to read
- **THEN** validation prints no version warning, as before

### Requirement: Validation warns about step references in player text
`ct.py validate` SHALL warn, without failing and naming the step, when its action text, `setup` or `expect` cites a step by number (`check 1.3`, `step 1.3`) or names one of the plan's own step ids. The card shows step titles, not ids, so the player cannot follow such a reference. `notes` and `reviewer` SHALL NOT be checked.

#### Scenario: Check number in expect
- **WHEN** a step's `expect` says "the vendor you opened in check 1.3"
- **THEN** validation prints a warning that names the step and says to describe what the player did

#### Scenario: Step id in setup
- **WHEN** a step's `setup` names another step's id
- **THEN** validation prints the same warning

#### Scenario: On purpose
- **WHEN** a step's `notes` say "on purpose", because the game shows the id in that text (a CheckThat chat line)
- **THEN** validation prints no reference warning for that step

#### Scenario: Reviewer line
- **WHEN** a `reviewer` line names a partner step id
- **THEN** validation prints no reference warning for it

### Requirement: A requirement may make a step inapplicable
A plan requirement MAY set `class` (class tokens such as `MAGE`), `profession` (profession names in the plan's locale) and `unmet` (`blocked`, the default, or `inapplicable`). Each given condition SHALL hold: the class token is listed, the character knows a listed profession, the probe passes. `ct validate` SHALL reject an unknown class token, and `unmet` without a condition.

#### Scenario: Class list
- **WHEN** a requirement sets `class: [MAGE, PRIEST]` and `unmet: inapplicable`
- **THEN** validation accepts it

#### Scenario: Unknown class
- **WHEN** a requirement sets `class: [WIZARD]`
- **THEN** validation fails and names the token

### Requirement: An auto step may be judged when the run starts
An `auto` step MAY set `async: true`. `ct validate` SHALL reject `async` on a step that is not `auto`, that has `setup`, `reload` or an entry `call`, or whose required assertions include an absence or an upper count.

#### Scenario: Async startup check
- **WHEN** an auto step with a `version` fact assertion sets `async: true`
- **THEN** validation accepts it

#### Scenario: Async absence
- **WHEN** an async step requires that a line is absent
- **THEN** validation fails, because an absence needs a time window

### Requirement: A pattern must be one that Lua can read
A log `pattern`, a `log-sequence` item `pattern` and the value of a `matches` operator SHALL be refused by `ct.py validate`, `ct.py compile` and plan import when the pattern is longer than 200 characters, or holds a NUL byte (write `%z`), or is a pattern that `string.find` raises on: an unclosed set, a lone trailing `%`, unbalanced captures, a back reference to a capture that is not closed, `%b` without two characters, `%f` without a set. A pattern with no special character is a plain text search and is always accepted. Every other pattern SHALL be accepted, as before. `tools/ct.py` and `Plan.lua` SHALL give the same answer and reason for every pattern.

#### Scenario: Ordinary linear patterns
- **WHEN** a plan uses `%d+%.?%d*`, `(%S+)%s+(.+)`, `.*%d+`, `^%s*(.-)%s*$` or `.-.-.-Z`
- **THEN** validation passes

#### Scenario: Pattern Lua cannot read
- **WHEN** a pattern is `(`, `x[a` or ends with a lone `%`
- **THEN** validation fails

#### Scenario: NUL byte
- **WHEN** a pattern holds a NUL byte
- **THEN** validation fails with "pattern has a NUL byte; write %z"

#### Scenario: Too long
- **WHEN** a pattern has 201 characters
- **THEN** validation fails with "pattern is longer than 200 characters"

### Requirement: A plan holds no null and no empty required text
`ct.py validate` SHALL refuse `null` anywhere in a plan except the tools-only `offline` block, and name its path. The schema SHALL give a `value` a type of text, number, boolean, list or object, and SHALL require a non-empty step `title`, a non-empty `expect` (or non-empty list items), a non-empty action `text`, and a non-empty fact `addon` and `key`.

#### Scenario: Empty YAML value
- **WHEN** a state assertion has `value:` with nothing after it
- **THEN** `ct.py validate` fails with the path of the value and "null is not allowed"

#### Scenario: Empty title
- **WHEN** a step has `title: ""`
- **THEN** `ct.py validate` fails, as plan import does

### Requirement: A plan may declare the plan revision it needs
A plan MAY hold a top-level `needs`, a positive integer plan revision. A plan without `needs` SHALL be revision 1, the format as of 0.21.0. CheckThat SHALL refuse a plan whose `needs` is above the revision it reads, before any other check and with only that reason, and SHALL tell the player that the plan needs a newer CheckThat.

#### Scenario: Newer plan on an older CheckThat
- **WHEN** a plan with `needs` one above the runner's revision, and with a key the runner does not know, is imported
- **THEN** the import fails with "This plan needs a newer CheckThat", gives no other error, and stores nothing

### Requirement: The tools write and check the plan revision
`ct.py compile` SHALL write `needs` when the plan uses a key added after revision 1, and SHALL NOT write it for a revision 1 plan. `ct.py validate` SHALL fail a `needs` that is not a positive integer, above the revision the tools read, or below the revision the plan's keys need.

#### Scenario: Revision 1 plan unchanged
- **WHEN** a plan that uses no later key is compiled
- **THEN** the compiled string has no `needs` and equals the string compiled before this change

#### Scenario: Stamp too low
- **WHEN** a plan uses a key of revision 2 and says `needs: 1`
- **THEN** `ct.py validate` fails and names the key

### Requirement: A plan may be for any addon
A plan's `addon` SHALL be any addon folder name of 1 to 64 letters, digits, `_`, `-`, `.` or `!`. A plan MAY hold `commands`, a list of 1 to 8 slash command prefixes, each one word after a slash. `commands` is plan revision 2.

#### Scenario: Unknown addon with its own prefix
- **WHEN** a plan for `MyAddon` lists `commands: [/my]` and a macro `/my debug on`
- **THEN** validation passes and compile writes `needs: 2`

#### Scenario: Unlisted prefix
- **WHEN** a plan for `MyAddon` without `commands` has a step command `/my debug on`
- **THEN** `ct.py validate` fails and says to list the prefix in `commands`

### Requirement: The runner offers a plan's commands only when the addon under test owns them
Before a Run button or the CT macro offers a command from the plan's `commands`, the runner SHALL check that the addon under test registered it (the game names the addon that wrote the `SLASH_` global). A command registered by another addon or by the game, or not registered, SHALL NOT be offered. Commands the addon declared through `CheckThat.Commands` SHALL be offered without that check. The start screen SHALL list the commands the plan may offer and those it does not.

#### Scenario: Registered by the addon under test
- **WHEN** the plan lists `/my` and `SLASH_MYADDON1 = "/my"` was written by MyAddon
- **THEN** a step with `/my debug on` gets a Run button

#### Scenario: Registered by another addon
- **WHEN** the plan lists `/oth` and another addon wrote the global
- **THEN** no Run button offers `/oth`, and the start screen names it as not offered

### Requirement: Short client names
A plan's `clients` SHALL accept `era` and `forever` as names for `classic-era` and `forever-camelot`. Compilation SHALL write the long names.

#### Scenario: Short name in a section
- **WHEN** a section has `clients: [era]` and the plan is compiled
- **THEN** each step of the section has `clients: [classic-era]`
