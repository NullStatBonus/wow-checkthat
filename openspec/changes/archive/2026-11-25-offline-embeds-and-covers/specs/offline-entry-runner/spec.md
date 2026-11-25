# Spec Delta

## ADDED Requirements

### Requirement: Runner follows XML files the TOC lists
The runner SHALL load an XML file named on a TOC line by loading each `Script` and `Include` file it names, in order, with paths relative to that XML file, and with the addon's own name and namespace as for a TOC line. XML comments SHALL be ignored. A `file` path that leaves the addon folder SHALL stop the run before any addon file loads and name the path.

#### Scenario: Libraries load through embeds.xml
- **WHEN** a TOC lists `embeds.xml`, which names a library file and includes a second XML file that names another
- **THEN** both library files load before the next TOC line, and an entry that uses them returns the expected values

#### Scenario: XML path leaves the addon folder
- **WHEN** an XML file the TOC lists names a file with `..` or an absolute path
- **THEN** the run fails with that path and no addon file has run

#### Scenario: Commented-out file
- **WHEN** an XML file holds a `Script` line inside an XML comment
- **THEN** that file does not load

### Requirement: Offline command checks covers against the addon's specs
`ct.py offline` SHALL validate the plan with the addon's spec requirements, as `validate` does, from `--specs` or from the `openspec/specs` folder found above the plan file.

#### Scenario: Plan with covers and a specs folder
- **WHEN** a plan whose steps carry `covers:` names requirements that exist in the specs folder given by `--specs`
- **THEN** the offline block runs

#### Scenario: Plan with covers and no specs folder
- **WHEN** a plan carries `covers:` and no specs folder is given or found
- **THEN** the command exits 2 and says that covers needs the specs folder

## MODIFIED Requirements

### Requirement: Offline command runs a plan's block
`ct.py offline <plan>` SHALL run the plan's offline block in the runner, resolving `toc` inside the folder given by `--addons` (default: the folder above the CheckThat checkout) and refusing a `toc` that leaves it. It SHALL print JUnit with one case for each step, exit 1 when a step fails, and exit 2 when the plan has no block, is not valid or the run cannot start.

#### Scenario: Wrong return
- **WHEN** a call step expects a value the entry does not return
- **THEN** that case fails and the exit code is 1

#### Scenario: Matching plan
- **WHEN** every step matches
- **THEN** the exit code is 0

#### Scenario: No block
- **WHEN** the plan has no offline block
- **THEN** the command exits 2 and says so

#### Scenario: Plan with covers and a specs folder
- **WHEN** a plan whose steps carry `covers:` names requirements that exist in the specs folder given by `--specs`
- **THEN** the offline block runs

#### Scenario: Plan with covers and no specs folder
- **WHEN** a plan carries `covers:` and no specs folder is given or found
- **THEN** the command exits 2 and says that covers needs the specs folder
