# test-plan-authoring Specification

## Purpose
Guides an addon developer from a scope of work to a validated CheckThat plan through an interview, a draft and a review, so plans cover the scope and use the evidence the addon already logs.

## Requirements

### Requirement: Skill asks before it assumes
The skill SHALL ask the author for the scope source (current branch, a diff or the session), the target addon, the output path, the plan locale, the depth, the clients in scope and the addon's debug log. It SHALL ask one question per turn, in dependency order, with the reason and a recommended answer where the repository supports one. It SHALL skip a question that the scope, specs or code already answer and say what it assumed. It SHALL suggest `plans/` as the output path and SHALL NOT guess an answer the author has not given.

#### Scenario: No scope given
- **WHEN** the author starts the skill without naming a scope
- **THEN** the skill asks whether to use the current branch, a diff or the session

#### Scenario: Default output path
- **WHEN** the skill asks where to write the plan
- **THEN** it suggests `plans/` and accepts another path

#### Scenario: Scope answers a question
- **WHEN** the OpenSpec change already names the addon and its slash prefix
- **THEN** the skill states them and does not ask for them

#### Scenario: One question per turn
- **WHEN** the interview starts
- **THEN** the skill asks one question and waits for the answer before the next

### Requirement: Skill finds the plan tools from any install
The skill SHALL locate `tools/ct.py`, `schema/test-plan.schema.json` and `docs/test-plan.md` in the bundle installed beside it, else in the checkout two folders above it. A path SHALL count as a root only when the plan tools and format files all exist under it. If it cannot find them, it SHALL ask the author for the CheckThat path and SHALL NOT assume the working directory is the CheckThat repository.

#### Scenario: Installed to the user's skills folder
- **WHEN** the author ran `make install-skill`, then removed or moved the checkout, and starts the skill in another addon repository
- **THEN** the skill finds the bundled tools and drafts without asking for a path

#### Scenario: Path unknown
- **WHEN** no bundle exists beside the skill and the tools are not in a checkout above it
- **THEN** the skill asks for the CheckThat checkout path before drafting

### Requirement: Make installs the skill for the user
`make install-skill` SHALL copy the skill folder and a bundle of the plan tools and format files into the user's skills folder, create a private Python environment there with the tools' dependencies, and replace an earlier copy. `SKILL_DIR` SHALL change the target folder. The install SHALL NOT change system Python, SHALL refuse a target folder inside the checkout, SHALL keep the earlier copy if any step fails, and SHALL stamp the bundle with the addon version.

#### Scenario: Install and update
- **WHEN** the author runs `make install-skill SKILL_DIR=<dir>` twice
- **THEN** `<dir>/ct-test-plan` holds the current skill files, the bundle and a working private Python

#### Scenario: Target inside the checkout
- **WHEN** `SKILL_DIR` points inside the checkout
- **THEN** the install fails and the skill source stays unchanged

#### Scenario: Dependencies cannot be installed
- **WHEN** the package download fails
- **THEN** the install fails with a message naming the step and the earlier installed copy stays unchanged

### Requirement: Evidence follows the target addon's log
The skill SHALL build assertions from the debug log the target addon already writes, using the SavedVariable name and format the author gives or the addon source shows. Where no log line proves a step, the skill SHALL use a player check and offer to open an issue for the missing log line.

#### Scenario: Behavior has no log line
- **WHEN** a changed behavior writes nothing to the addon's log
- **THEN** the step uses a player check and the skill offers an issue for the missing evidence

### Requirement: Draft covers the scope and passes validation
The skill SHALL cover each changed requirement or scenario in the scope with at least one step, add a regression step for the nearest unchanged behavior, and write the plan for one locale. It SHALL run `tools/ct.py validate` on the draft and report each problem with its step ID. It SHALL list every slash command named in step text in that step's `commands`.

#### Scenario: Validation fails
- **WHEN** `validate` rejects the draft
- **THEN** the skill reports each problem with the step ID and fixes the draft before review

#### Scenario: Command named in text
- **WHEN** a step text names a slash command
- **THEN** the step lists it in `commands`

### Requirement: Author reviews by bulk or step by step
The skill SHALL draft and review one step at a time, showing each step with its evidence choice and client tags and applying only what the author accepts. A rejected new step SHALL stay out of the plan. A rejected edit to an accepted step SHALL leave that step unchanged. Accept all SHALL be available when the author asks. After the last step the skill SHALL show coverage gaps and checklist findings, validate and compile each plan.

#### Scenario: Step-by-step review
- **WHEN** the author chooses step by step
- **THEN** the skill shows each step with its findings and applies only the changes the author accepts

#### Scenario: Step rejected
- **WHEN** the author rejects a drafted step
- **THEN** the skill leaves it out and moves to the next step

#### Scenario: Edit rejected
- **WHEN** the author rejects a change to an accepted step
- **THEN** the step stays as accepted

### Requirement: Skill validates with the bundled Python
The skill SHALL run the plan tools with the private Python in its own folder when one exists, and SHALL report the bundle's version stamp with the validation result. Without a private Python, as in a plugin install, it SHALL use `python3` when that imports PyYAML and jsonschema. When a package is missing it SHALL stop, print the command that creates an environment and installs `requirements.txt`, and SHALL NOT claim the plan was validated.

#### Scenario: Validate a draft
- **WHEN** the skill validates a draft
- **THEN** it runs the bundled `ct.py` with the private Python and reports the bundle version

#### Scenario: Plugin install without packages
- **WHEN** the skill runs from a plugin and `python3` lacks PyYAML or jsonschema
- **THEN** it prints the setup command and stops without validating

### Requirement: Skill guides an addon that has no debug log
When the target addon writes no debug log, the skill SHALL say so once, recommend adding one, and point to the debug-logging guide. It SHALL draft the plan with player checks, SHALL mark the steps that would become log assertions once a log exists, and SHALL NOT invent log lines.

#### Scenario: Addon has no debug log
- **WHEN** the author says the addon has no debug log
- **THEN** the skill recommends adding one, points to the guide, and asks whether to add it now or draft with player checks

#### Scenario: Log added later
- **WHEN** the plan was drafted without a log
- **THEN** each step that would gain a log assertion is marked, so the plan can be upgraded

### Requirement: Skill offers issues for missing log evidence
For steps with no log evidence the skill SHALL offer to open issues in the addon's repository. When the addon has no debug log it SHALL offer one issue for the log facility plus one per needed line, naming the steps each unlocks. It SHALL ask first and SHALL NOT open an issue unasked.

#### Scenario: No log facility
- **WHEN** the author accepts issues for an addon with no debug log
- **THEN** the skill drafts one issue for the facility and one per needed line, each listing the steps it unlocks

### Requirement: A debug-logging guide ships with the skill
The repository SHALL hold `docs/debug-logging.md`, which describes the shared debug-log pattern and what makes a line worth asserting on, with example lines from the sample addons. `make install-skill` SHALL install it in the bundle, and the skill SHALL read it when it judges evidence.

#### Scenario: Guide installed
- **WHEN** the author runs `make install-skill`
- **THEN** the installed bundle holds `docs/debug-logging.md`

### Requirement: Skill guides when a step may settle itself
The skill SHALL mark a step `auto` only when its required assertions are unconditional log lines or state probes that settle the step alone, as the existing rule for required checks demands. It SHALL ask the author for a timeout when auto-fail is wanted, SHALL tell the author the timeout covers the player's own action time plus the result, and SHALL leave steps that need a human judgment manual.

#### Scenario: Step needs judgment
- **WHEN** a step's expected result is that something looks right on screen
- **THEN** the skill leaves it manual

#### Scenario: Auto-fail wanted
- **WHEN** the author wants a failed step to be recorded without a click
- **THEN** the skill asks for a timeout and explains what it counts

### Requirement: Skill drafts simple steps by default
By default the skill SHALL draft each step with one player action and one expected result, in short active sentences. When a check needs more, the skill SHALL split it into consecutive steps. It SHALL draft a compound step, with several actions, several expected results or a multi-part assertion set, only when the author asks, and SHALL say that it does so.

#### Scenario: Check needs two actions
- **WHEN** a check needs the player to open a window and then press a button
- **THEN** the skill drafts two steps, one action each

#### Scenario: Author asks for a complex check
- **WHEN** the author asks for one step that covers a sequence
- **THEN** the skill drafts it as one step and states that it is compound

### Requirement: Skill splits cross-character checks into one plan per role
The skill SHALL ask which characters a check involves. For a check that needs more than one it SHALL draft one plan per character role, named `<name>.<role>.yaml`, with no limit on roles. Each plan SHALL be runnable by its character alone. Each preamble SHALL name every partner plan, and a `reviewer` line SHALL name the partner files, the step IDs and the relationship that must hold. The skill SHALL validate and compile every plan and state the import order.

#### Scenario: Two-character check
- **WHEN** a check needs a run left by one character and an observation by another
- **THEN** the skill drafts two plan files and each preamble names the other

#### Scenario: Many characters
- **WHEN** a check compares results from four characters
- **THEN** the skill drafts four plans and each preamble names the other three

#### Scenario: Single-character scope
- **WHEN** every check needs one character
- **THEN** the skill drafts one plan and asks no further character question

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
