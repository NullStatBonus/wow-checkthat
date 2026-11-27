## ADDED Requirements

### Requirement: The card shows a step's cleanup
After a step has a pass, partial, fail or skip result, the card SHALL show the step's `cleanup` text: under the result while the card holds it, and at the top of the next step until that step has a result. A reload SHALL keep it. Undo or Redo of that step, or another run, SHALL hide it.

#### Scenario: Pass moves on
- **WHEN** a step with cleanup gets Fail and the card shows the next step
- **THEN** the next step starts with "First, after the last step:" and the cleanup text

#### Scenario: Next step recorded
- **WHEN** the next step gets a result
- **THEN** the cleanup line is gone
