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
Each step SHALL have a stable `id` independent of numbering, `title`, `action`, `expect` in player-visible words, and `verify` modes; and MAY have `clients`, `requires`, `setup`, `assertions`, `reviewer`, `cleanup`, `reload`, `notes`. Sections group steps and MAY add shared `requires`, `setup` and `clients`, which compilation SHALL merge into every member step. A plan MAY carry a once-per-run `preamble` and a `handoff`.

#### Scenario: Section prerequisites inherited
- **WHEN** a section declares a requirement
- **THEN** every step in it lists that requirement after compilation

### Requirement: Actions are a closed set of kinds
`action.kind` SHALL be one of `manual`, `copy-slash`, `secure-macro`, `reload`, `wait-event`. An action MAY list `commands` offered as copy text. Every slash command, copy text and macro body SHALL be limited to the runner-shipped allow list for the plan's addon plus `/reload` and `/console scriptErrors 0|1`. A plan SHALL NOT extend that list. No kind SHALL cause game input without a user keypress or click. A `wait-event` action SHALL be valid only on an auto step.

#### Scenario: Unknown action kind
- **WHEN** a step uses `kind: cast`
- **THEN** validation fails

#### Scenario: Plan tries to allow its own commands
- **WHEN** a plan macro contains `/run`, `/script`, `/cast`, or another addon's slash command
- **THEN** validation fails, in the compiler and on import

#### Scenario: Wait-event without auto
- **WHEN** a step uses `kind: wait-event` and is not an auto step
- **THEN** validation fails

### Requirement: Assertions and probes are typed
Assertions SHALL be `log` (named log source, one of equals, contains, pattern, with scope attempt or session, optional absent), `log-sequence` (ordered matchers), or `state` (probe from a closed registry: addon-loaded, global-value, frame-shown; operator; value). Any assertion MAY be `diagnostic`, recorded but never gating. `verify` SHALL be a set of `player`, `assertions`, `reviewer`; `assertions` requires assertions to exist and vice versa; `reviewer` requires reviewer text kept verbatim.

#### Scenario: Unknown probe
- **WHEN** an assertion names a probe absent from the registry
- **THEN** validation fails

#### Scenario: Ordered evidence
- **WHEN** a step needs "off" logged before "on"
- **THEN** a `log-sequence` passes only if the lines appear in that order inside the attempt window

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
A plan MAY hold a top-level `offline` object with `toc`, optional `tocs` (an object with `era` and `forever` TOC paths, at least one), `mocks`, `mockAfterLoad`, `level` (1 to 5) and `savedVariables`, and either `steps` or `groups`. Each step is one of a `call` (addon, entry, literal `args`) with `returns` or `throws`, an `event` (name, literal `args`), a `mockCalls` count, `reload: true`, or `wait` (seconds, 0 to 86400). `savedVariables` maps a global name to a literal value. Each group holds `steps` and optional `label`, `mocks` and `savedVariables`. `reload`, `groups` and `savedVariables` SHALL be valid only with `level` 3 or more, `wait` only with `level: 4`, and `tocs` only with `level: 5`. `ct.py offline --client` reads `tocs`; without that option only `toc` runs, and a plan without `tocs` validates and runs as before. Validation SHALL reject any other shape. Compile SHALL remove the block, so the compiled string and its digest do not contain it.

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
- **WHEN** an offline block says `level: 5`, and another says `level: 6`
- **THEN** validation passes the first and fails the second

#### Scenario: One TOC for each client
- **WHEN** a block at level 5 holds `tocs` with an `era` path, a `forever` path, or both, and another block holds `tocs` with a `retail` key or an empty object
- **THEN** validation passes the first and fails the second

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
