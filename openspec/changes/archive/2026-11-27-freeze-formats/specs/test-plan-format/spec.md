## ADDED Requirements

### Requirement: Short client names
A plan's `clients` SHALL accept `era` and `forever` as names for `classic-era` and `forever-camelot`. Compilation SHALL write the long names.

#### Scenario: Short name in a section
- **WHEN** a section has `clients: [era]` and the plan is compiled
- **THEN** each step of the section has `clients: [classic-era]`
