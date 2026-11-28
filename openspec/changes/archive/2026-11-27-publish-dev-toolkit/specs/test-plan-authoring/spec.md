## ADDED Requirements

### Requirement: Release publishes the plugin through a marketplace
The repository SHALL hold `.claude-plugin/marketplace.json`. It SHALL name the `checkthat` plugin with this repository's `plugin` branch as the source. A release workflow run for a tag, or a manual run on `main` with `publish` set, SHALL build the plugin, check it with `claude plugin validate`, and commit it to the `plugin` branch. A failed validation SHALL stop the run before anything is published.

#### Scenario: Install from the marketplace
- **WHEN** a developer runs `claude plugin marketplace add NullStatBonus/wow-checkthat` and installs `checkthat` after a release
- **THEN** `/checkthat:plan` and `/checkthat:verify` are available with the tools of that release

#### Scenario: Tools-only change reaches users
- **WHEN** the tools change without an addon version bump and the maintainer runs the workflow on `main` with `publish` set
- **THEN** the `plugin` branch gets a new commit, no tag or GitHub release is created, and an installed plugin sees an update

#### Scenario: Invalid plugin
- **WHEN** `claude plugin validate` rejects the built plugin during a release
- **THEN** the workflow fails and the `plugin` branch keeps its previous commit

### Requirement: Plugin version names the addon version and the commit
`make build-plugin` SHALL set the plugin version to the addon's `## Version:` followed by `+` and the short commit it was built from, such as `1.0.0+3f9c2a1b7d4e`, so each publish is a new version. The bundle's `VERSION` SHALL stay the plain addon version.

#### Scenario: Two publishes of one addon version
- **WHEN** the plugin is built from two commits while the TOC says 1.0.0
- **THEN** the two `plugin.json` versions differ and both start with `1.0.0+`, and both bundles say `1.0.0` in `VERSION`

### Requirement: Release publishes an agent-neutral toolkit
`make build-toolkit` SHALL build `build/CheckThat-toolkit-<version>.zip`. The zip SHALL hold `ct-test-plan/` and `ct-verify/` in the layout `make install-skill` writes, with the bundle and its `VERSION` stamp and without a private Python. A tag release SHALL attach this zip to its GitHub release. A manual publish run SHALL replace the zip on the existing release of the current addon version and SHALL NOT create a release.

#### Scenario: Unzip into a skills folder
- **WHEN** a developer unzips the toolkit into an agent's skills folder and runs `ct-test-plan/ct/tools/ct validate <plan>` with a Python that has the requirements
- **THEN** the plan validates, and `ct-verify` finds the tools in `../ct-test-plan/ct`

### Requirement: One bundle step
`make install-skill`, `make build-plugin` and `make build-toolkit` SHALL copy the bundle with one shared step, so their `ct/` folders hold the same files.

#### Scenario: Same bundle in every output
- **WHEN** all three targets run from one checkout
- **THEN** the `ct/` folders of the installed skill, the plugin and the toolkit hold the same files with the same contents

### Requirement: Setup creates the private Python
`ct setup` SHALL create a per-user Python environment outside the installed tools, in the user data folder (`$XDG_DATA_HOME/checkthat/venv`, default `~/.local/share/checkthat/venv`; `%LOCALAPPDATA%\checkthat\venv` on Windows), and install `requirements.txt` into it, so the environment outlives a plugin update. `ct setup` SHALL NOT change system Python. Run again, it SHALL replace the environment only after the new one installs. A failure SHALL name the missing piece: `venv` or network access.

#### Scenario: Plugin install gets a private Python
- **WHEN** a developer runs `ct setup` from a plugin or toolkit install whose `python3` lacks PyYAML
- **THEN** the skill then runs the tools with the new private Python and validates a plan

#### Scenario: Environment survives a plugin update
- **WHEN** the plugin updates to a new version after `ct setup` ran
- **THEN** the new version's skills find the per-user environment and need no second setup

### Requirement: Tools find the per-user Python
The `ct` launcher and both skills SHALL look for Python in this order: the private Python beside the skill from `make install-skill`, the per-user environment from `ct setup`, then `python3`. A skill that finds no Python with PyYAML and jsonschema SHALL name `ct setup` instead of the manual venv commands.

#### Scenario: Install-skill Python wins
- **WHEN** both the private Python from `make install-skill` and the per-user environment exist
- **THEN** the launcher runs `ct.py` with the private Python

#### Scenario: No usable Python
- **WHEN** no private Python and no per-user environment exist and `python3` lacks PyYAML
- **THEN** the skill stops, names `ct setup`, and does not claim the plan was validated

### Requirement: Doctor reports tool prerequisites
`ct doctor` SHALL print a tools section. It names the tools version (`VERSION`, or the checkout's TOC version), the Python in use and whether it imports PyYAML and jsonschema, and whether `luajit` is on the path. For each missing piece it SHALL print the command that fixes it on the current platform, and `ct setup` for the Python packages. The section SHALL NOT change the exit code, which keeps its meaning for saved variables.

#### Scenario: LuaJIT missing
- **WHEN** `ct doctor` runs on macOS without `luajit` on the path
- **THEN** the tools section says LuaJIT is missing, prints `brew install luajit`, and the exit code is the same as with LuaJIT installed

### Requirement: Missing LuaJIT names its install
When a command that needs LuaJIT cannot start it, the error SHALL name the install command for the current platform and `ct doctor`. It SHALL keep the existing text `this command needs luajit, which is not installed` at its start.

#### Scenario: Offline without LuaJIT
- **WHEN** `ct offline <plan>` runs on Linux without `luajit`
- **THEN** the error starts with the existing text and names `apt install luajit` and `ct doctor`

### Requirement: Bundle tests are internal
The docs for the installed skill SHALL state that the bundle's `tests/` files serve the plan commands and are not a contract for an addon's own tests.

#### Scenario: Developer reads the install docs
- **WHEN** a developer reads `docs/skills.md`
- **THEN** it says that `tests/` in the bundle is internal and names issue #273
