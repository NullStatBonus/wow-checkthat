# test-plan-authoring Specification

## Purpose
Guides an addon developer from a scope of work to a validated CheckThat plan through an interview, a draft and a review, so plans cover the scope and use the evidence the addon already logs.

## Requirements

### Requirement: Skill asks before it assumes
The skill SHALL ask the author for the scope source (current branch, a diff or the session), the target addon, the output path, the plan locale, the depth, the clients in scope and the addon's debug log. It SHALL suggest `plans/` as the output path and SHALL NOT guess an answer the author has not given.

#### Scenario: No scope given
- **WHEN** the author starts the skill without naming a scope
- **THEN** the skill asks whether to use the current branch, a diff or the session

#### Scenario: Default output path
- **WHEN** the skill asks where to write the plan
- **THEN** it suggests `plans/` and accepts another path

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
After the draft the skill SHALL show coverage gaps and checklist findings, and SHALL let the author accept all suggestions or go through the plan step by step. It SHALL NOT change a step the author has rejected.

#### Scenario: Step-by-step review
- **WHEN** the author chooses step by step
- **THEN** the skill shows each step with its findings and applies only the changes the author accepts

### Requirement: Skill validates with the bundled Python
The skill SHALL run the plan tools with the private Python in its own folder and SHALL report the bundle's version stamp with the validation result.

#### Scenario: Validate a draft
- **WHEN** the skill validates a draft
- **THEN** it runs the bundled `ct.py` with the private Python and reports the bundle version

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
