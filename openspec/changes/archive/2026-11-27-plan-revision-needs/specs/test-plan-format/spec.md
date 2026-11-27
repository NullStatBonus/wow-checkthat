## ADDED Requirements

### Requirement: A plan may declare the plan revision it needs
A plan MAY hold a top-level `needs`, a positive integer plan revision. A plan without `needs` SHALL be revision 1, the format as of 0.21.0. CheckThat SHALL refuse a plan whose `needs` is above the revision it reads, before any other check and with only that reason, and SHALL tell the player that the plan needs a newer CheckThat.

#### Scenario: Newer plan on an older CheckThat
- **WHEN** a plan with `needs` one above the runner's revision, and with a key the runner does not know, is imported
- **THEN** the import fails with "This plan needs a newer CheckThat", gives no other error, and stores nothing

### Requirement: The tools write and check the plan revision
`ct.py compile` SHALL write `needs` when the plan uses a key added after revision 1, and SHALL NOT write it for a revision 1 plan. `ct.py validate` SHALL fail a `needs` that is not a positive integer, above the revision the tools read, or below the revision the plan's keys need.

#### Scenario: Revision 1 plan unchanged
- **WHEN** a plan that uses no later key is compiled
- **THEN** the compiled string has no `needs` and equals the string compiled before this change

#### Scenario: Stamp too low
- **WHEN** a plan uses a key of revision 2 and says `needs: 1`
- **THEN** `ct.py validate` fails and names the key
