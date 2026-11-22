## ADDED Requirements

### Requirement: Only unconditional log checks may be required
A converted check SHALL be a required assertion only when its log line is emitted on every correct run of the step and was confirmed in the addon source or a saved log. A line that depends on a race, an optional addon, a character, or an event order SHALL stay diagnostic or reviewer-only. Steps that apply to one client SHALL list that client.

#### Scenario: Conditional line
- **WHEN** a log line appears only if the game reports a move after a window closes
- **THEN** the step keeps it diagnostic

#### Scenario: Client-specific step
- **WHEN** a step is for Classic Era only
- **THEN** it lists `classic-era` and is inapplicable on Forever

### Requirement: The runner has a self-test plan
The project SHALL ship a plan for the runner itself that exercises each action kind and an evidence assertion, runnable without any sibling addon.

#### Scenario: Self-test validates
- **WHEN** the self-test plan is compiled
- **THEN** it validates and decodes in the addon
