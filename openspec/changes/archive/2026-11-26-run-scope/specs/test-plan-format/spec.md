## MODIFIED Requirements

### Requirement: Assertions and probes are typed
Assertions SHALL be `log` (named log source, one of equals, contains, pattern, with scope attempt, run or session, optional absent), `log-sequence` (ordered matchers), or `state` (probe from a closed registry: addon-loaded, global-value, frame-shown; operator; value). Scope `attempt` reads the lines written after the step's attempt opened, `run` the lines written after the current run started (across `/reload`), and `session` the whole retained log. Any assertion MAY be `diagnostic`, recorded but never gating. `verify` SHALL be a set of `player`, `assertions`, `reviewer`; `assertions` requires assertions to exist and vice versa; `reviewer` requires reviewer text kept verbatim.

#### Scenario: Unknown probe
- **WHEN** an assertion names a probe absent from the registry
- **THEN** validation fails

#### Scenario: Ordered evidence
- **WHEN** a step needs "off" logged before "on"
- **THEN** a `log-sequence` passes only if the lines appear in that order inside the attempt window

#### Scenario: Run scope accepted
- **WHEN** a log assertion sets `scope: run`
- **THEN** `ct validate` and plan import accept it

#### Scenario: Unknown scope
- **WHEN** an assertion sets `scope: forever`
- **THEN** validation fails with "bad scope"
