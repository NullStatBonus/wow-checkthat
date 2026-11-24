## MODIFIED Requirements

### Requirement: The start flow offers categories
The Home page and the card start screen SHALL list each category of the chosen plan with a checkbox in plan order, all checked, with its step count. Start run SHALL be off, with a line saying why, when none is checked. A plan with one category SHALL show no list. The card start screen SHALL list up to eight categories inline. A plan with more SHALL show a Choose categories button that opens a window with the same checkboxes, fourteen rows at a time, scrolling with the mouse wheel and with page buttons. The Home page SHALL list twenty-four categories at a time with page buttons when the plan has more. Both lists SHALL change the same picked set.

#### Scenario: Pick two
- **WHEN** the tester clears two checkboxes and selects Start run
- **THEN** the run starts with the other categories picked

#### Scenario: None picked
- **WHEN** the tester clears every checkbox
- **THEN** Start run is off and a line says "Select at least one category."

#### Scenario: Thirty categories on the card
- **WHEN** a plan has thirty categories and the tester selects Choose categories
- **THEN** a window lists fourteen with page buttons, and a box cleared there is also cleared on Home

#### Scenario: Thirty categories on Home
- **WHEN** a plan has thirty categories
- **THEN** Home lists twenty-four, and Next page shows the other six

## ADDED Requirements

### Requirement: Verdicts have optional key bindings
The game's key bindings window SHALL list CheckThat actions for Pass, Partial, Fail and Skip, with no key assigned by default. Each action SHALL record the same result as its card button, with the note from the card. An action SHALL do nothing and say why when no run is active or the card is hidden. No binding SHALL send a protected action.

#### Scenario: Unbound by default
- **WHEN** the addon loads for the first time
- **THEN** no key triggers a verdict

#### Scenario: A bound key
- **WHEN** the tester presses a key bound to Pass on a step
- **THEN** the step passes as if Pass was clicked and the card shows the next step

#### Scenario: No run
- **WHEN** the tester presses a bound key with no active run
- **THEN** nothing is recorded and a line says there is no current step
