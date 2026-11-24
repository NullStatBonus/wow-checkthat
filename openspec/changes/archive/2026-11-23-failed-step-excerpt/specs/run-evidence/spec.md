## ADDED Requirements

### Requirement: A failed attempt keeps the log lines that arrived
When an attempt records fail or unverified, it SHALL keep, for each log its step checks (not `session` scope), the first 20 new lines, each cut to 200 characters, as `excerpt`. A pass SHALL keep none. A log that cannot be read, or whose start is lost, SHALL add none. The results string SHALL stay version 1. The report SHALL print the lines under the attempt.

#### Scenario: A failure
- **WHEN** a step fails after 30 new log lines
- **THEN** its attempt holds the first 20, each at most 200 characters, and the report prints them

#### Scenario: A pass
- **WHEN** a step passes
- **THEN** its attempt holds no excerpt
