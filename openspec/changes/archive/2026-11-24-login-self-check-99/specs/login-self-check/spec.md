# Spec Delta

## Purpose
Let a developer check an addon's registered entries after login without opening a run, and keep it off for everyone else.

## ADDED Requirements

### Requirement: Opt-in login self-check
CheckThat SHALL have a profile setting `loginCheck`, off by default. When on, about 3 seconds after login and not in combat, it SHALL call each entry named by an auto step with a `call` in the imported plans, compare the outcome line with the step's required `equals` and `contains` log checks, and print one chat line with the matched and total counts and the first miss. It SHALL record no fact and open no run. When off it SHALL call nothing.

#### Scenario: Matching entry
- **WHEN** the setting is on and the entry returns what the step expects
- **THEN** chat says "Self-check: 1 of 1 entry checks matched." and no fact is recorded

#### Scenario: Wrong value
- **WHEN** the entry returns another value
- **THEN** chat names the step and the line it read

#### Scenario: Setting off or in combat
- **WHEN** the setting is off, or the player is in combat after login
- **THEN** no entry is called and chat stays silent
