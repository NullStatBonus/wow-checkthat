# Spec Delta

## ADDED Requirements

### Requirement: Step may call an entry
A step MAY hold `call: {addon, entry, args}` only when it is an auto step. `addon` and `entry` SHALL be names of the same form as a fact's addon and key, and `args` SHALL be a list of at most 8 strings, numbers or booleans. Validation SHALL reject any other field or shape, in the game and in the tools.

#### Scenario: Call on a manual step
- **WHEN** a step has `call` and is not auto
- **THEN** validation fails
