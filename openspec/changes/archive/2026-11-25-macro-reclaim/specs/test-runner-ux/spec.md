# Spec Delta

## MODIFIED Requirements

### Requirement: The CT macro can follow the current step
When the setting "Keep the CT macro on the current step" is on, CheckThat SHALL rewrite the CT macro each time the current step changes. The body SHALL be the line `/ct macrorun <step id>` followed by the step's commands, never a result command. A step with no usable commands SHALL get the marker and `/ct status`. CheckThat SHALL rewrite only a macro it made. A macro the player changed SHALL stay as it is for the rest of the run. A new run, or turning the setting on, SHALL take it back while its first line is still the marker.

#### Scenario: Step changes
- **WHEN** the setting is on, the tester is out of combat and the current step changes
- **THEN** the CT macro holds the marker for the new step, then the new step's commands

#### Scenario: Step without commands
- **WHEN** the new current step has no commands
- **THEN** the CT macro holds the marker, then `/ct status`

#### Scenario: No result command
- **WHEN** the macro is rewritten for any step
- **THEN** its body contains no `/ct pass`, `/ct partial`, `/ct fail` or `/ct skip`

#### Scenario: The player edited the macro
- **WHEN** the tester changed the body of the CT macro and the step changes
- **THEN** CheckThat does not edit that macro and does not claim it follows the step

#### Scenario: A new run takes the macro back
- **WHEN** the tester changed the macro in an earlier run, its first line is still the marker, and a new run shows its first step
- **THEN** the CT macro holds the marker and commands of that step

#### Scenario: The marker was removed
- **WHEN** the tester removed the marker line from the macro
- **THEN** CheckThat leaves the macro alone in every later run

#### Scenario: Setting off
- **WHEN** the setting is off and the step changes
- **THEN** the CT macro is not rewritten
