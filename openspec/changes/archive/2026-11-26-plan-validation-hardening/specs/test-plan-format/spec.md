## ADDED Requirements

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
