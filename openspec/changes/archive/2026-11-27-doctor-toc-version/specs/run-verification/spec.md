## ADDED Requirements

### Requirement: Doctor compares the installed version
`ct.py doctor` SHALL, for each client folder it reports, compare the `## Version:` of the installed CheckThat with the checkout's. It SHALL print a warning naming both versions when they differ and SHALL treat a missing install as a note. It SHALL NOT change its exit code for a mismatch.

#### Scenario: Older install
- **WHEN** the era client has CheckThat 0.16.0 installed and the checkout is 0.21.0
- **THEN** doctor prints "warning: installed CheckThat 0.16.0, checkout 0.21.0"

#### Scenario: Same version
- **WHEN** the installed version equals the checkout's
- **THEN** doctor prints no warning
