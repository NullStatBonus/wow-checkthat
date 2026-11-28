## MODIFIED Requirements

### Requirement: Assertions and probes are typed

Assertions SHALL be `log` (named log source, one of equals, contains, pattern, with scope attempt, run or session, optional absent), `log-sequence` (ordered matchers, and an item after the first MAY give `within`), or `state` (probe from a closed registry: addon-loaded, global-value, frame-shown; operator; value). Scope `attempt` reads the lines written after the step's attempt opened, `run` the lines written after the current run started (across `/reload`), and `session` the whole retained log. Any assertion MAY be `diagnostic`, recorded but never gating. `verify` SHALL be a set of `player`, `assertions`, `reviewer`; `assertions` requires assertions to exist and vice versa; `reviewer` requires reviewer text kept verbatim.

#### Scenario: Ordered evidence
- **WHEN** a step needs "off" logged before "on"
- **THEN** a `log-sequence` passes only if the lines appear in that order inside the attempt window

## ADDED Requirements

### Requirement: A sequence item may name a gap

An item of a `log-sequence` after the first MAY give `within`: the whole number of seconds, 1 to 600, within which its line SHALL be written after the line matched by the item before it. `ct validate`, `ct compile` and plan import SHALL refuse `within` on the first item, a `within` that is not a whole number, and a value below 1 or above 600. The check SHALL read the time of every line of its window; a source that keeps no time for its lines, and a window with a line whose time cannot be read, SHALL leave the check unverified with "this log keeps no time for these lines, so a within check cannot be judged". When the lines appear in order but a gap is longer than its `within`, the check SHALL be unverified with "sequence stopped at item N", where N is the item whose line it could not place, and never failed. An earlier line of an item that leaves too little time SHALL NOT fail a check that a later line of the same item satisfies. A plan that gives `within` SHALL need plan revision 3: `ct compile` SHALL write `needs: 3`, and a reader of revision 2 SHALL refuse the plan with "needs a newer CheckThat".

#### Scenario: Two lines in time
- **WHEN** a sequence's second item gives `within: 2` and its line is written 2 seconds after the first item's line
- **THEN** the check passes

#### Scenario: A line too late
- **WHEN** the second line is written 3 seconds after the first
- **THEN** the check is unverified with "sequence stopped at item 2"

#### Scenario: A log with no times
- **WHEN** the source's lines carry no time
- **THEN** the check is unverified and never passes

#### Scenario: The first item
- **WHEN** the first item of a sequence gives `within`
- **THEN** validation fails
