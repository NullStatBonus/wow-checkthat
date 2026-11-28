## MODIFIED Requirements

### Requirement: The start screen lists what a plan reads
Under the step count, the start screen SHALL list the globals that the plan's log sources, `global-value` checks and `frame-text` checks read, sorted, at most six and then "and N more", with the sentence that a results string can include what they hold. A plan that reads none SHALL show no line. A `frame-shown` check SHALL NOT be listed. Names SHALL be cut to 40 characters with `|` doubled.

#### Scenario: A plan that reads a log
- **WHEN** a plan with a log source on `KeepThatDB` is ready to start
- **THEN** the start screen says "This plan reads these variables: KeepThatDB. A results string can include what they hold."

#### Scenario: A plan that reads a frame's text
- **WHEN** a plan has a `frame-text` check on `MerchantFrame`
- **THEN** the list names `MerchantFrame`

#### Scenario: A plan that reads nothing
- **WHEN** a plan has no log source, no `global-value` check and no `frame-text` check
- **THEN** the start screen shows no such line
