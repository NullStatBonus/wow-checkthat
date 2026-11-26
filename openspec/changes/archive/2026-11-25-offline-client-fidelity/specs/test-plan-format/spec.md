# Spec Delta

## MODIFIED Requirements

### Requirement: Plan may carry an offline block
A plan MAY hold a top-level `offline` object with `toc`, optional `mocks`, `mockAfterLoad` and `level` (1 or 2), and `steps`. Each step is one of a `call` (addon, entry, literal `args`) with `returns` or `throws`, an `event` (name, literal `args`), or a `mockCalls` count. Validation SHALL reject any other shape. Compile SHALL remove the block, so the compiled string and its digest do not contain it.

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
- **WHEN** an offline block says `level: 2`, and another says `level: 3`
- **THEN** validation passes the first and fails the second
