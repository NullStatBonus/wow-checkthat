# Spec Delta

## ADDED Requirements

### Requirement: The CT macro can follow the current step
When the setting "Keep the CT macro on the current step" is on, CheckThat SHALL rewrite the CT macro with the current step's commands each time the current step changes. The macro SHALL contain commands only, never a result command. A step with no usable commands SHALL get the body `/ct status`. CheckThat SHALL rewrite only a macro it made and the player has not changed.

#### Scenario: Step changes
- **WHEN** the setting is on, the tester is out of combat and the current step changes
- **THEN** the CT macro holds the new step's commands

#### Scenario: Step without commands
- **WHEN** the new current step has no commands
- **THEN** the CT macro holds `/ct status`

#### Scenario: No result command
- **WHEN** the macro is rewritten for any step
- **THEN** its body contains no `/ct pass`, `/ct partial`, `/ct fail` or `/ct skip`

#### Scenario: The player edited the macro
- **WHEN** the tester changed the body of the CT macro and the step changes
- **THEN** CheckThat does not edit that macro and does not claim it follows the step

#### Scenario: Setting off
- **WHEN** the setting is off and the step changes
- **THEN** the CT macro is not rewritten

### Requirement: A macro change waits for the end of combat
CheckThat SHALL NOT create or edit a macro in combat. A step change in combat SHALL queue one rewrite for the step that is current when combat ends.

#### Scenario: Step changes in combat
- **WHEN** the setting is on and the current step changes twice in combat
- **THEN** the macro is unchanged during combat and holds the latest step's commands after combat

### Requirement: The card says when a step has no macro
When the setting is on and the current step has commands that no macro can hold, the card SHALL show one line saying so. A step with no commands SHALL show no such line.

#### Scenario: Too many commands
- **WHEN** the current step lists more commands than the card offers, or the commands exceed the macro length limit
- **THEN** the macro holds `/ct status` and the card line says the step has no macro

### Requirement: A macro rewrite is logged
Each rewrite SHALL log `macro set <step id>` in the debug log.

#### Scenario: Log line
- **WHEN** the macro is rewritten for step `ct.abc`
- **THEN** the debug log has the line `macro set ct.abc`
