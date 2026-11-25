# Spec Delta

## ADDED Requirements

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
