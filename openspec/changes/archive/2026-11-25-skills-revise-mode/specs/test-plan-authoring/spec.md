# Spec Delta

## ADDED Requirements

### Requirement: Revise a plan after a run
The skill SHALL, when the author has a finished run, read the verify report and its version warnings first, sort each failed, unverified or contradicted step as a plan fault, an addon fault or unknown, edit only plan faults, keep every step id and run the handoff gate again. It SHALL say whether the next run is `/ct rerun failed` (plan unchanged) or a new import (plan changed) and SHALL point to `ct.py diff` for the comparison. It SHALL NOT edit addon code unasked.

#### Scenario: Pattern stricter than the line
- **WHEN** a failed step's hit shows a near match of its pattern
- **THEN** the skill calls it a plan fault and edits the pattern

#### Scenario: Forbidden line present
- **WHEN** a step failed because an `absent` line appeared
- **THEN** the skill calls it an addon fault and edits nothing

#### Scenario: Run of another build
- **WHEN** the report warns that the run used another addon version or plan file
- **THEN** the skill stops and asks for a new run
