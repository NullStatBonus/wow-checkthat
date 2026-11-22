# Spec Delta

## MODIFIED Requirements

### Requirement: Skill finds the plan tools from any install
The skill SHALL locate `tools/wtt.py`, `schema/test-plan.schema.json` and `docs/test-plan.md` in the bundle installed beside it, else in the checkout two folders above it. A path SHALL count as a root only when the plan tools and format files all exist under it. If it cannot find them, it SHALL ask the author for the TestThat path and SHALL NOT assume the working directory is the TestThat repository.

#### Scenario: Installed to the user's skills folder
- **WHEN** the author ran `make install-skill`, then removed or moved the checkout, and starts the skill in another addon repository
- **THEN** the skill finds the bundled tools and drafts without asking for a path

#### Scenario: Path unknown
- **WHEN** no bundle exists beside the skill and the tools are not in a checkout above it
- **THEN** the skill asks for the TestThat checkout path before drafting

### Requirement: Make installs the skill for the user
`make install-skill` SHALL copy the skill folder and a bundle of the plan tools and format files into the user's skills folder, create a private Python environment there with the tools' dependencies, and replace an earlier copy. `SKILL_DIR` SHALL change the target folder. The install SHALL NOT change system Python, SHALL refuse a target folder inside the checkout, SHALL keep the earlier copy if any step fails, and SHALL stamp the bundle with the addon version.

#### Scenario: Install and update
- **WHEN** the author runs `make install-skill SKILL_DIR=<dir>` twice
- **THEN** `<dir>/wtt-test-plan` holds the current skill files, the bundle and a working private Python

#### Scenario: Target inside the checkout
- **WHEN** `SKILL_DIR` points inside the checkout
- **THEN** the install fails and the skill source stays unchanged

#### Scenario: Dependencies cannot be installed
- **WHEN** the package download fails
- **THEN** the install fails with a message naming the step and the earlier installed copy stays unchanged

## ADDED Requirements

### Requirement: Skill validates with the bundled Python
The skill SHALL run the plan tools with the private Python in its own folder and SHALL report the bundle's version stamp with the validation result.

#### Scenario: Validate a draft
- **WHEN** the skill validates a draft
- **THEN** it runs the bundled `wtt.py` with the private Python and reports the bundle version
