## ADDED Requirements

### Requirement: Each result has a sound
When a step gets a result, CheckThat SHALL play one sound from its own files: `tick` for a pass, partial, fail or skip the player recorded; `chime-up` for a pass CheckThat recorded; `chime-down` for a fail CheckThat recorded; `attention` for an unverified result from either path. Sounds SHALL play on the game's SFX channel, also while the card is hidden or collapsed.

#### Scenario: Automatic pass
- **WHEN** CheckThat records a pass on an automatic step
- **THEN** `chime-up` plays and the log has `sound chime-up for <step id>`

#### Scenario: Player result
- **WHEN** the player presses Pass, Partial, Fail or Skip
- **THEN** `tick` plays

#### Scenario: Unverified
- **WHEN** an automatic step reaches its timeout without its evidence, or the player presses Pass and the evidence is missing
- **THEN** `attention` plays

#### Scenario: Card hidden
- **WHEN** the card is hidden and CheckThat records a pass
- **THEN** `chime-up` plays

### Requirement: One sound for the passes at run start
Steps that pass when the run starts SHALL play one `chime-up` together, named for the first of them.

#### Scenario: Passes at run start
- **WHEN** three async steps pass as the run starts
- **THEN** `chime-up` plays once

### Requirement: The run's last result plays finish
When a result leaves the run with no open step, CheckThat SHALL play `finish` in place of that result's sound.

#### Scenario: Last step passed
- **WHEN** the player presses Pass on the last open step
- **THEN** `finish` plays and `tick` does not

### Requirement: Sounds can be previewed
`/ct sound <name>` SHALL play the named sound whether or not a run is open and log `sound <name> for preview`. An unknown name SHALL list the five names.

#### Scenario: Preview
- **WHEN** the player types `/ct sound attention`
- **THEN** `attention` plays

### Requirement: Missing sound support is silent
When the game cannot play a sound file, CheckThat SHALL record results as usual, raise no error and play nothing.

#### Scenario: No PlaySoundFile
- **WHEN** `PlaySoundFile` is missing or fails
- **THEN** the result is recorded and no error appears
