## MODIFIED Requirements

### Requirement: Skill validates with the bundled Python
The skill SHALL run the plan tools with the private Python in its own folder when one exists, and SHALL report the bundle's version stamp with the validation result. Without a private Python, as in a plugin install, it SHALL use `python3` when that imports PyYAML and jsonschema. When a package is missing it SHALL stop, print the command that creates an environment and installs `requirements.txt`, and SHALL NOT claim the plan was validated.

#### Scenario: Validate a draft
- **WHEN** the skill validates a draft
- **THEN** it runs the bundled `ct.py` with the private Python and reports the bundle version

#### Scenario: Plugin install without packages
- **WHEN** the skill runs from a plugin and `python3` lacks PyYAML or jsonschema
- **THEN** it prints the setup command and stops without validating

## ADDED Requirements

### Requirement: The repository builds a plugin
`make build-plugin` SHALL build a Claude Code plugin folder that holds `ct-test-plan`, `ct-verify`, the plan tools with the files that `collect` needs, and the version stamp. The plugin SHALL pass `claude plugin validate`. `make install-skill` SHALL keep working.

#### Scenario: Build and validate
- **WHEN** `make build-plugin` runs
- **THEN** the folder holds the manifest, both skills and the tools, and `claude plugin validate` accepts it

#### Scenario: Decode from the built plugin
- **WHEN** `collect` runs from the built plugin on a saved variables file with one run
- **THEN** it extracts that run

### Requirement: Apply and archive offer a plan
The OpenSpec apply and archive operations SHALL offer the plan skill when a change alters player-visible behavior, where the repository's `openspec/config.yaml` carries that guidance. The offer SHALL be optional and SHALL NOT start the skill unasked.

#### Scenario: Behavior change
- **WHEN** a change alters a setting or a command
- **THEN** apply offers the plan skill and waits for the author's answer

#### Scenario: Offer declined
- **WHEN** the author declines the offer
- **THEN** nothing starts and apply continues
