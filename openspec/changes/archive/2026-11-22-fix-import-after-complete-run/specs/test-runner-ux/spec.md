## ADDED Requirements

### Requirement: A new plan takes focus
Importing a plan, or choosing one from Recent plans, SHALL make it the pending plan. While a plan is pending the card SHALL show it with Start run, whether no run exists, the last run is complete, or a run is unfinished. With an unfinished run the card SHALL also offer Resume run; Resume SHALL return to that run unchanged. Starting a run SHALL clear the pending plan.

#### Scenario: Import after a finished run
- **WHEN** a run is complete and the player imports another plan
- **THEN** the card shows the new plan with Start run and no Resume

#### Scenario: Import during an unfinished run
- **WHEN** a run is unfinished and the player imports another plan
- **THEN** the card offers Start run and Resume run, and Resume returns to the unfinished run
