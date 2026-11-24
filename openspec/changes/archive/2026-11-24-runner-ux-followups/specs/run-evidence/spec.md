## MODIFIED Requirements

### Requirement: One error stack for each attempt
CheckThat SHALL ask for an error stack only when a step opens a new attempt, not when the card refreshes an attempt that is already open. A verdict from a slash command that opens an attempt SHALL ask for a stack in the same way as the card.

#### Scenario: Card refresh
- **WHEN** the card refreshes a step whose attempt is open
- **THEN** no second stack is requested

#### Scenario: Slash verdict
- **WHEN** a verdict from a slash command opens a new attempt
- **THEN** that attempt is armed for a stack

## ADDED Requirements

### Requirement: The report matches stacks to each attempt
`report --stacks` in the json and junit formats SHALL attach the stacks to the attempt whose open time holds them, also for an attempt that failed and was followed by a pass. A recovered failure's stacks SHALL appear in the junit `system-out` of its step. The "time also fits another attempt" label SHALL stay.

#### Scenario: Fail then pass
- **WHEN** a step failed with an error stack, was retried and passed
- **THEN** the json report holds the stack on the failed attempt and the junit step lists it in system-out

### Requirement: A reopened step shows no old evidence
After Undo or a rerun, a pending step SHALL show "awaiting retry" with evidence `none` in the report table, not the earlier attempt's note and evidence.

#### Scenario: Rerun
- **WHEN** a step with a failed attempt with bad evidence is reopened
- **THEN** the table shows awaiting retry and evidence none, and the earlier attempt stays in the export
