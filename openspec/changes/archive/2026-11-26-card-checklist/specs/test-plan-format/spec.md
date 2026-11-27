## MODIFIED Requirements

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

## ADDED Requirements

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
