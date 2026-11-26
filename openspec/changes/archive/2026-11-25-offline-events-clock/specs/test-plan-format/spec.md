## MODIFIED Requirements

### Requirement: Plan may carry an offline block
A plan MAY hold a top-level `offline` object with `toc`, optional `mocks`, `mockAfterLoad`, `level` (1, 2, 3 or 4) and `savedVariables`, and either `steps` or `groups`. Each step is one of a `call` (addon, entry, literal `args`) with `returns` or `throws`, an `event` (name, literal `args`), a `mockCalls` count, `reload: true`, or `wait` (seconds, 0 to 86400). `savedVariables` maps a global name to a literal value. Each group holds `steps` and optional `label`, `mocks` and `savedVariables`. `reload`, `groups` and `savedVariables` SHALL be valid only with `level` 3 or more, and `wait` only with `level: 4`. Validation SHALL reject any other shape. Compile SHALL remove the block, so the compiled string and its digest do not contain it.

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
- **WHEN** an offline block says `level: 4`, and another says `level: 5`
- **THEN** validation passes the first and fails the second

#### Scenario: Reload below level 3
- **WHEN** a block at level 2 holds a `reload` step, `groups` or `savedVariables`
- **THEN** validation fails

#### Scenario: Wait below level 4
- **WHEN** a block at level 3 holds a `wait` step, in its steps or in a group
- **THEN** validation fails

#### Scenario: Steps and groups
- **WHEN** a block holds both `steps` and `groups`
- **THEN** validation fails
