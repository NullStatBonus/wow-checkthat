## MODIFIED Requirements

### Requirement: An auto step records its own pass
While an auto step has an open attempt, the runner SHALL re-read the required assertions at least twice a second, whether or not the card is shown. When every required assertion is met, the runner SHALL record the pass by the same evidence gate as a player's pass, with the claim labelled `auto`, and SHALL move to the next pending step. Reading and recording SHALL send no input and SHALL start no game action.

#### Scenario: Hidden card
- **WHEN** the awaited log line appears while an auto step is open and the card is hidden
- **THEN** the step records pass with evidence matched and claim auto, and the next step is current

#### Scenario: Line appears
- **WHEN** the awaited log line appears while an auto step is open
- **THEN** the step records pass with evidence matched and claim auto, without a button press

#### Scenario: Not all met
- **WHEN** one of two required assertions is met and the other is waiting
- **THEN** the step stays open and records nothing

#### Scenario: Player clicks first
- **WHEN** the player records fail on an auto step before its checks are met
- **THEN** the step records the player's result and the runner does not record another

#### Scenario: Undo
- **WHEN** the player undoes an automatic pass or any later result of the step
- **THEN** the step reopens and the runner can settle it again

#### Scenario: Reload requested
- **WHEN** an auto step asks for a reload after the action and its checks are met before the reload happened
- **THEN** the runner waits for the reload, and the timeout still settles the step

#### Scenario: Check changes between reads
- **WHEN** a check reads met on the card refresh but not when the runner records the result
- **THEN** the runner records nothing and tries again on the next refresh
