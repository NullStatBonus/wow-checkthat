## ADDED Requirements

### Requirement: A saved run says which format and which CheckThat wrote it
A run SHALL carry `ct` (the major version), `formatRev` (the newest revision that wrote it, never lowered by a writer) and `writerVersion` (the CheckThat version that last changed it, omitted when unknown). A finished attempt SHALL carry `formatRev`. A run saved before has none of these and a reader SHALL treat their absence as unknown. The results string SHALL stay version 1.

#### Scenario: A new run
- **WHEN** a run starts and an attempt finishes
- **THEN** the run holds `ct`, `formatRev` and `writerVersion`, and the attempt holds `formatRev`

#### Scenario: An older writer
- **WHEN** a run with a higher `formatRev` is changed by this version
- **THEN** its `formatRev` stays at the higher value

### Requirement: A run of a newer major format is kept aside untouched
When the addon loads, a run whose `ct` is higher than the major it knows, or is present and not a whole number, SHALL be moved, as the same table, out of the runs the addon uses, SHALL NOT be counted, shown, resumed, pruned or changed, and its plan SHALL be kept (when the run names none, the plans stored at that moment). The addon SHALL tell the player how many such runs there are.

#### Scenario: Kept aside
- **WHEN** the saved variables hold a run with a higher `ct` and the runs are pruned
- **THEN** that run is unchanged and takes no place in the limit

### Requirement: A run set aside keeps its id and comes back safely
A new run SHALL NOT take the id of a run set aside. A run set aside SHALL move back when the addon reads its major, and never over a readable run with the same id.

#### Scenario: A namesake
- **WHEN** a readable run appears with the id of a run set aside and the addon then reads that run's major
- **THEN** both runs stay where they are

### Requirement: The tools refuse a newer major before they read it
`ct.py` SHALL refuse a run whose `ct` is higher than it reads, or present and not a whole number, before it checks any other key, SHALL name the file and the number, and SHALL accept a higher `formatRev`. `collect` and `import-results` SHALL refuse such a run; `collect` SHALL store nothing of it and SHALL keep the refusal until a revision at least as new is stored. `report` SHALL warn when it shows an older revision, or none, because a newer one could not be read, and `report --strict` SHALL fail.

#### Scenario: A refusal outlives the collect
- **WHEN** `collect` refused a run and an older revision of it is stored
- **THEN** `report --strict` exits 1 until a revision at least as new as the refused one is stored

#### Scenario: A newer revision of a run
- **WHEN** the newest revision file of a run is in a newer major format and an older one is readable
- **THEN** `status` names the file and the reason, `report` warns, and `report --strict` exits 1

### Requirement: The format page matches the code
`docs/results-format.md` SHALL state the current `ct` and `formatRev` and list a row for the current revision, and a test SHALL fail when it does not agree with `Run.MAJOR`, `Run.FORMAT_REV` and the major `ct.py` reads.

#### Scenario: A revision without a row
- **WHEN** `Run.FORMAT_REV` is raised and the page is not updated
- **THEN** the tools tests fail
