# Spec Delta

## MODIFIED Requirements

### Requirement: The CT macro can follow the current step
When the setting "Keep the CT macro on the current step" is on, CheckThat SHALL rewrite the CT macro each time the current step changes. The body SHALL be the line `/ct macrorun <step id>` followed by the step's commands, never a result command. A step with no usable commands SHALL get the marker and `/ct status`. CheckThat SHALL rewrite only a macro it made and the player has not changed.

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

#### Scenario: Setting off
- **WHEN** the setting is off and the step changes
- **THEN** the CT macro is not rewritten

### Requirement: The card says when a step has no macro
When the setting is on and the current step has commands that no macro can hold, the card SHALL show one line saying so. A step with no commands SHALL show no such line. The commands that fit are counted together with the marker line.

#### Scenario: Too many commands
- **WHEN** the current step lists more commands than the card offers, or the marker and the commands exceed the macro length limit
- **THEN** the macro holds the marker and `/ct status`, and the card line says the step has no macro

## ADDED Requirements

### Requirement: A macro press names its step
The body that `/ct macro` writes SHALL follow the same layout as the follow setting: the marker line first. The Run button SHALL NOT run the marker. When the marker runs, CheckThat SHALL tell a press for the current step from a press for another step, so a plan and a reviewer can see a macro pressed out of sync.

#### Scenario: Macro key on the current step
- **WHEN** the tester presses the macro key on the step the macro was written for
- **THEN** the debug log has `macro run <step id>`

#### Scenario: Macro key after the step moved
- **WHEN** the step moved in combat and the tester presses the macro key before the macro is rewritten
- **THEN** chat says the macro is for the old step and the card shows another, and the debug log has `macro stale <old id> card <current id>`

#### Scenario: Run button
- **WHEN** the tester clicks Run
- **THEN** the debug log has no `macro run` line

#### Scenario: Marker removed
- **WHEN** the tester removed the marker line from the macro and presses it
- **THEN** the debug log has no `macro run` or `macro stale` line
