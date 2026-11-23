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
A step MAY set `auto: true`. An auto step SHALL list `assertions` in `verify`, SHALL NOT list `player` in `verify`, SHALL have at least one required assertion, and SHALL have no required absence assertion. Validation SHALL reject an auto step that breaks any of these rules, in the compiler and on import.

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
- **THEN** validation fails

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
