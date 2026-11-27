# plan-transport Specification

## Purpose
Versioned, checksummed strings that carry plans in and results out of the game.

## Requirements

### Requirement: Plans and results use a versioned string
Exported strings SHALL be `!CT1!`, an 8-hex Adler-32 of the canonical JSON, `!`, then base64 of raw-deflate-compressed canonical JSON (sorted keys, ASCII only). Import SHALL reject unknown versions, bad checksums, malformed base64 or JSON, and encoded strings over 120,000 characters, without partial import. A decoded payload SHALL declare `kind` as `plan` or `results`.

#### Scenario: Corrupt string
- **WHEN** a pasted string has a bad checksum
- **THEN** import fails with a message and no state changes

#### Scenario: Round trip
- **WHEN** a plan is decoded, re-encoded, and decoded again
- **THEN** the two tables are deeply equal

#### Scenario: Compiler and addon agree
- **WHEN** the Python compiler encodes a plan
- **THEN** the addon decodes and validates it

### Requirement: Imported plans are data only
Imported content SHALL never be executed. Slash commands and macro bodies SHALL be checked against the runner-shipped allow list on import and again before being offered.

#### Scenario: Code in a field
- **WHEN** a plan field contains Lua source or a disallowed command
- **THEN** import is rejected or it is shown as text and never loaded

### Requirement: Import bounds decoded size while decoding
Import SHALL stop decompressing once the decoded output passes 2,000,000 bytes and reject the string as too large. The work and memory used before rejection SHALL stay bounded by that cap, not by the size the string claims to expand to.

#### Scenario: Highly compressible string
- **WHEN** a pasted string of under 120,000 characters would decode to far more than 2,000,000 bytes
- **THEN** import fails with a "too large" message and no state changes
- **AND** decoding stops shortly after the cap instead of producing the full output

#### Scenario: Normal plan
- **WHEN** a plan whose decoded size is under the cap is pasted
- **THEN** import succeeds exactly as before

### Requirement: Import refuses a plan whose fields have the wrong type
`Plan.Validate` SHALL refuse a plan in which a field that the card or the evidence code reads has the wrong type: a log source, a requirement or the `logs` and `requirements` tables that is not a table; a log source `global` or `path`, a requirement `text`, `preamble`, `handoff`, a section `intro`, `setup` or `title`, a step `setup` or an assertion `label` that is not text; `equals`, `contains` or `pattern` of a log assertion or sequence item that is not text; a sequence item that is not a table; `macros`, `requires`, `clients`, `assertions` or `commands` that is not a list. Optional fields stay optional. The import SHALL store nothing for such a plan.

#### Scenario: Hand-made string with a wrong type
- **WHEN** an imported plan has `logs.debug` as text, or an assertion `contains` as a number
- **THEN** the import fails with "The plan is not valid" and the plan is not stored

### Requirement: Compile refuses a string over the import cap
`ct.py compile` SHALL fail with a message that names the length and the limit when the compiled string is longer than 120000 characters, the limit the addon's `Codec.Decode` enforces.

#### Scenario: Too long
- **WHEN** a compiled plan is 130000 characters
- **THEN** `ct.py compile` exits 1 and writes no string
