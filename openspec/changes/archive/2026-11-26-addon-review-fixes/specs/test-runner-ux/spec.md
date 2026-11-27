## ADDED Requirements

### Requirement: The start screen lists what a plan reads
Under the step count, the start screen SHALL list the globals that the plan's log sources and `global-value` checks read, sorted, at most six and then "and N more", with the sentence that a results string can include what they hold. A plan that reads none SHALL show no line. A `frame-shown` check SHALL NOT be listed. Names SHALL be cut to 40 characters with `|` doubled.

#### Scenario: A plan that reads a log
- **WHEN** a plan with a log source on `KeepThatDB` is ready to start
- **THEN** the start screen says "This plan reads these variables: KeepThatDB. A results string can include what they hold."

#### Scenario: A plan that reads nothing
- **WHEN** a plan has no log source and no `global-value` check
- **THEN** the start screen shows no such line

### Requirement: A profile switch moves the Categories window
When the profile changes, is copied or is reset, the card and the Categories window SHALL take their place and look from the new profile at once.

#### Scenario: Switch profile
- **WHEN** the player switches to a profile that has no saved place for the Categories window
- **THEN** the window moves to its default place with no reload
