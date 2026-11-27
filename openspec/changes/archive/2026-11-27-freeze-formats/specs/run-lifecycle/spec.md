## ADDED Requirements

### Requirement: An unknown client is not guessed
CheckThat SHALL name the client `classic-era` for an interface number from 11000 to 11999 and `forever-camelot` from 16000 to 16999, and SHALL leave it unknown otherwise. With an unknown client only the steps without `clients` SHALL run.

#### Scenario: Another client
- **WHEN** the interface number is 20505
- **THEN** the client is unknown and a step tagged `classic-era` does not run

### Requirement: Open lists in the run record
Readers of a run SHALL accept a value they do not know in `by`, `evidence` and `at` on an attempt and in `kind`, `scope` and `since` on an outcome. A new value in `verdict` or `result` SHALL need a new major.

#### Scenario: A newer evidence kind
- **WHEN** a run has an outcome with `kind: sound`
- **THEN** `ct.py report` reads it and shows the value
