## ADDED Requirements

### Requirement: Plans declare the cap of the addon's debug log
The sample and full plans for an addon whose debug log has a known bound SHALL declare that bound as `cap` on the debug log source, and `tools/ct.py` SHALL add it to a plan built from a test-plan file. The source file and line of each bound SHALL be in `docs/contracts.md`.

#### Scenario: Plans and tool agree
- **WHEN** a plan declares a debug log for an addon the tool knows
- **THEN** its `cap` equals the tool's value

### Requirement: A guide says which tool to use
`docs/tools-guide.md` SHALL say what each of wowless, BugGrabber, BugSack and CheckThat does and cannot do, with the pages it is based on and the date they were read. It SHALL name the other addons as optional. CheckThat SHALL declare no required dependency.

#### Scenario: Optional addons
- **WHEN** the TOC files are read
- **THEN** neither declares `Dependencies` or `RequiredDeps`
