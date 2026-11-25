# Spec Delta

## ADDED Requirements

### Requirement: Macro follow setting
The settings page SHALL offer "Keep the CT macro on the current step". It SHALL be off by default and stored in the profile. Its help text SHALL say that the macro runs commands only and that the tester still presses a result key. The debug report SHALL show its value as `macroFollow`. Changing it SHALL log `macroFollow on` or `macroFollow off`.

#### Scenario: Default
- **WHEN** the addon loads for the first time
- **THEN** the setting is off and the debug report shows `macroFollow` as off

#### Scenario: Turned on
- **WHEN** the tester turns the setting on during a run, out of combat
- **THEN** the CT macro is set to the current step's commands at once
