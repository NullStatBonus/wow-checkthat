## ADDED Requirements

### Requirement: Compare runs by the version of the addon under test
`ct.py diff` SHALL show the `targetVersion` of each run in its header, and "?" for a run that has none. `ct.py trend --by target` SHALL name each column by it. `--by version` SHALL keep naming the CheckThat version.

#### Scenario: Header
- **WHEN** a run with `targetVersion` is diffed against one without
- **THEN** the header shows the version for the first and "?" for the second

#### Scenario: Trend by target
- **WHEN** `trend --by target` reads runs of two addon versions
- **THEN** each column is labelled with its run's `targetVersion`
