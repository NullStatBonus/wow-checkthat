# Spec Delta

## ADDED Requirements

### Requirement: Plans may declare categories
A plan MAY set `categories`: a list of objects with a unique `id` (lower case letters, digits, dot, dash), a `title` and an optional `intro`. A step or section MAY set `category` to a declared id. A plan that declares categories SHALL have every step resolve to one. Unknown fields and unknown ids SHALL fail validation, in the compiler and on import.

#### Scenario: Unknown category id
- **WHEN** a step names a category the plan does not declare
- **THEN** validation fails and names the step and the id

#### Scenario: Section default
- **WHEN** a section sets `category: bank`
- **THEN** every step in it lists `bank` after compilation unless it names its own

### Requirement: Fact assertions check typed values
An assertion MAY have `kind: fact` with `source` (a log source), `addon`, `key` and an operator `op`. Operators SHALL be `eq`, `ne`, `gt`, `ge`, `lt`, `le`, `between` (value is a list of two numbers), `approx` (with `tolerance`), `in` (value is a list), `matches`, `contains`, `type` (number, boolean or string), `exists` and `missing`. An assertion MAY set `which` to `last`, `any` or `all`; the default is `last`. A value of the wrong shape for its operator SHALL fail validation.

#### Scenario: Between needs two numbers
- **WHEN** a fact assertion uses `between` with one value
- **THEN** validation fails

#### Scenario: Unknown operator
- **WHEN** a fact assertion uses `op: near`
- **THEN** validation fails

### Requirement: Log and fact assertions may count matches
A `log` or `fact` assertion MAY set `count` with `exactly`, `min` or `max`, each a whole number from 0 to 1000. `exactly` SHALL NOT combine with `min` or `max`, and `min` SHALL NOT exceed `max`. `count` SHALL NOT combine with `absent`.

#### Scenario: Count with absent
- **WHEN** an assertion sets both `count` and `absent`
- **THEN** validation fails

#### Scenario: Called exactly twice
- **WHEN** an assertion sets `count: { exactly: 2 }`
- **THEN** the plan validates

### Requirement: A log source may be quiet
A log source MAY set `quiet: true`, meaning that no new lines is a valid result. The default SHALL stay not quiet.

#### Scenario: Error log source
- **WHEN** a plan declares a source with `quiet: true`
- **THEN** the plan validates

### Requirement: State probes accept more operators
A `state` assertion SHALL accept the existing operators and also `ge`, `le`, `between`, `approx`, `matches`, `type`, `in` and `missing`, with the value shapes of fact assertions.

#### Scenario: Range on a global
- **WHEN** a state assertion reads a global with `op: between` and `value: [1, 5]`
- **THEN** the plan validates

### Requirement: A check that something did not happen is judged at the timeout
A required assertion that is an absence check, a fact check with the operator `missing`, or a count with `exactly` or `max` SHALL be judged when an auto step's timeout ends, as more lines can arrive until then. An auto step with such an assertion SHALL set `timeout`. It SHALL settle as fail at once when the check can no longer hold.

#### Scenario: Absence check with a timeout
- **WHEN** an auto step has a required absence check and `timeout: 10`
- **THEN** validation passes, and the step records pass after 10 seconds if the line never appeared

#### Scenario: No timeout
- **WHEN** an auto step has a required count with `exactly: 2` and no `timeout`
- **THEN** validation fails and says the step needs a timeout

#### Scenario: Broken before the timeout
- **WHEN** a third matching line arrives in a step that needs exactly two
- **THEN** the step records fail at once

#### Scenario: Lower bound
- **WHEN** an auto step has a required count with only `min: 2`
- **THEN** it needs no timeout and settles as soon as two lines are in

### Requirement: A log source may declare its capacity
A log source MAY set `cap`, a whole number from 1 to 100000: how many lines the log keeps before it drops the oldest. A log that holds fewer lines than `cap` SHALL count as never rolled, so the line where a step began is certain.

#### Scenario: Alike lines under the cap
- **WHEN** a source with `cap: 100` holds three identical lines and a step needs no new line
- **THEN** the check can pass, as the step began after the third line

#### Scenario: Bad cap
- **WHEN** a source sets `cap: 0`
- **THEN** validation fails

## MODIFIED Requirements

### Requirement: A step may be settled by its own evidence
A step MAY set `auto: true`. An auto step SHALL list `assertions` in `verify`, SHALL NOT list `player` in `verify`, and SHALL have at least one required assertion. An auto step with a required check that something did not happen SHALL set `timeout`. Validation SHALL reject an auto step that breaks any of these rules, in the compiler and on import.

#### Scenario: Auto step with a required line
- **WHEN** a step sets `auto: true`, verifies by assertions only, and has a required log assertion
- **THEN** validation passes

#### Scenario: Auto step that needs the player
- **WHEN** a step sets `auto: true` and lists `player` in `verify`
- **THEN** validation fails

#### Scenario: Auto step with only diagnostic assertions
- **WHEN** a step sets `auto: true` and every assertion is diagnostic
- **THEN** validation fails

#### Scenario: Auto step with an absence check
- **WHEN** a step sets `auto: true` and a required assertion checks that a line is absent
- **THEN** validation fails unless the step also sets `timeout`
