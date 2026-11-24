# Spec Delta

## ADDED Requirements

### Requirement: Category commands
`/ct categories` SHALL list each category with its title, its id, its state word and counts, and an overall line. `/ct run <category or step id>` SHALL add and show a category or show a step. `/ct rerun <category>` SHALL ask, then reopen a category. Each SHALL reject surplus input and unknown names with a usage line and change nothing. `/ct help runs` and the About page SHALL list them.

#### Scenario: List
- **WHEN** the tester types `/ct categories` during a run
- **THEN** one line per category shows "Bank (bank): failed, 1 passed, 1 failed, 0 open" and a last line shows the overall result

#### Scenario: No run
- **WHEN** the tester types `/ct run bank` with no run
- **THEN** a line says there is no run

#### Scenario: Surplus input
- **WHEN** the tester types `/ct categories now please`
- **THEN** a usage line shows and nothing changes

#### Scenario: Categories window
- **WHEN** the tester types `/ct tracker`
- **THEN** the Categories window opens, or closes if it was open, and `/ct tracker now` is refused with a usage line

#### Scenario: Self-test commands
- **WHEN** the tester types `/ct selftest facts` or `/ct selftest error` during a run
- **THEN** the test facts are reported, or a test error is passed to the error handler
