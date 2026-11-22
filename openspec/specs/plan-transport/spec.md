# plan-transport Specification

## Purpose
Versioned, checksummed strings that carry plans in and results out of the game.

## Requirements

### Requirement: Plans and results use a versioned string
Exported strings SHALL be `!WTT1!`, an 8-hex Adler-32 of the canonical JSON, `!`, then base64 of raw-deflate-compressed canonical JSON (sorted keys, ASCII only). Import SHALL reject unknown versions, bad checksums, malformed base64 or JSON, and encoded strings over 120,000 characters, without partial import. A decoded payload SHALL declare `kind` as `plan` or `results`.

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
