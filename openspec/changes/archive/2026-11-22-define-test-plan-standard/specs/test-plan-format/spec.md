## ADDED Requirements

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
`action.kind` SHALL be one of `manual`, `copy-slash`, `secure-macro`, `reload`, `wait-event`. An action MAY list `commands` offered as copy text. Every slash command, copy text and macro body SHALL be limited to the runner-shipped allow list for the plan's addon plus `/reload` and `/console scriptErrors 0|1`. A plan SHALL NOT extend that list. No kind SHALL cause game input without a user keypress or click.

#### Scenario: Unknown action kind
- **WHEN** a step uses `kind: cast`
- **THEN** validation fails

#### Scenario: Plan tries to allow its own commands
- **WHEN** a plan macro contains `/run`, `/script`, `/cast`, or another addon's slash command
- **THEN** validation fails, in the compiler and on import

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
