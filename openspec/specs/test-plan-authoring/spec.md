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
The skill SHALL cover each changed requirement or scenario in the scope that a fake game cannot prove with at least one step, add a regression step for the nearest unchanged behavior, and write the plan for one locale. It SHALL run `tools/ct.py validate` on the draft and report each problem with its step ID. It SHALL list every slash command named in step text in that step's `commands`.

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
For steps with no log evidence the skill SHALL offer to open issues in the addon's repository. Each issue SHALL name a log line or a fact that the addon could publish with `CheckThat.Report`, the guarded call and its key, and the steps it unlocks. When the addon has no debug log it SHALL offer one issue for the log facility plus one per needed line or fact. It SHALL ask first and SHALL NOT open an issue unasked.

#### Scenario: No log facility
- **WHEN** the author accepts issues for an addon with no debug log
- **THEN** the skill drafts one issue for the facility and one per needed line or fact, each listing the steps it unlocks

#### Scenario: A value with no log line
- **WHEN** a step proves a value that the addon does not log
- **THEN** the skill offers a fact beside a new log line, names the guarded `CheckThat.Report` call and key, and writes no assertion for a fact the addon does not yet report

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

### Requirement: Compilation merges categories
Compilation SHALL write a section's `category` into each of its steps that has none, and SHALL leave the plan's `categories` as declared.

#### Scenario: Merge
- **WHEN** a section sets a category and a step in it sets another
- **THEN** the step keeps its own and the others take the section's

### Requirement: Parameterized steps expand at compile time
A step MAY set `cases`, a list of up to 50 objects with a unique `id` suffix and `vars`. Compilation SHALL replace each `{{name}}` in the step's text and assertions with the case's var, SHALL give each expanded step the id `<id>.<suffix>`, and SHALL remove `cases`. An unknown placeholder or a duplicate suffix SHALL fail compilation. The runner SHALL NOT see `cases`.

#### Scenario: Three cases
- **WHEN** a step with id `bind` has cases `cloth`, `leather` and `mail`
- **THEN** the plan holds the steps `bind.cloth`, `bind.leather` and `bind.mail`

#### Scenario: Unknown placeholder
- **WHEN** step text names `{{slot}}` and a case has no `slot` var
- **THEN** compilation fails and names the step and the case

#### Scenario: Plan with cases imported
- **WHEN** a plan string that still holds `cases` is imported
- **THEN** validation fails

### Requirement: Plans declare the cap of the addon's debug log
The sample and full plans for an addon whose debug log has a known bound SHALL declare that bound as `cap` on the debug log source, and `tools/ct.py` SHALL add it to a plan built from a test-plan file. The source file and line of each bound SHALL be in `docs/contracts.md`.

#### Scenario: Plans and tool agree
- **WHEN** a plan declares a debug log for an addon the tool knows
- **THEN** its `cap` equals the tool's value

### Requirement: A guide says which tool to use
`docs/tools-guide.md` SHALL say what CheckThat does not do and which addons make it better, with the pages it is based on and the date they were read. It SHALL name only addons CheckThat works with, as optional. CheckThat SHALL declare no required dependency.

#### Scenario: Optional addons
- **WHEN** the TOC files are read
- **THEN** neither declares `Dependencies` or `RequiredDeps`

### Requirement: Skill sets auto and manual steps apart
The skill SHALL ask the author for each step whether it is auto or manual, SHALL end the `expect` text of a manual step with the press it needs, and SHALL default an auto step's `timeout` to 120 seconds while saying it counts from when the step opens.

#### Scenario: Manual step text
- **WHEN** the skill drafts a manual step
- **THEN** its `expect` text ends with the press that records the result

### Requirement: Skill replays the compiled plan before review
After `compile` the skill SHALL run `tests/replay_plan.lua` on the plan and SHALL show the result in the review. A plan whose replay reports a problem SHALL NOT be called final.

#### Scenario: A step never settles
- **WHEN** the replay reports a step that does not settle
- **THEN** the review lists the step and the plan stays open

### Requirement: Skill warns about a stale bundle
When `$CT/VERSION` and a checkout both exist and differ, the skill SHALL warn that the bundle is stale and name `make install-skill`.

#### Scenario: Bundle older than checkout
- **WHEN** `$CT/VERSION` is 0.16.0 and the checkout is 0.17.0
- **THEN** the skill tells the author to run `make install-skill`

### Requirement: Handoff gate before a tester runs a plan
The skill SHALL run `validate`, `compile`, `replay-flow`, `lines` and (when the plan has one) `offline`, then an independent review of the plan against what the card shows, and SHALL fix every finding in the same session. It SHALL say plainly when a step was not run, and which plan version an earlier in-game run used.

#### Scenario: No luajit
- **WHEN** `luajit` is missing
- **THEN** the skill says the plan was not replayed

### Requirement: Step ids stay put
The skill SHALL tell the author never to renumber or rename an existing step id. `ct.py diff` SHALL mark a step that kept its text and changed its id as renamed and warn that its history is split.

#### Scenario: Renamed step
- **WHEN** two runs of different plan versions hold a step with the same text under different ids
- **THEN** `diff` shows "renamed to" and "renamed from" and a warning

### Requirement: Offline question in the interview
The interview SHALL ask which scope items need no client and draft those as offline steps first.

#### Scenario: Pure function in scope
- **WHEN** a scope item is a classification the addon exposes as an entry
- **THEN** the skill drafts an offline step for it before any player step

### Requirement: Optional pull request block
The skill SHALL offer a pull request block with one unticked checkbox for each manual check and plan step, each with its full text.

#### Scenario: Manual check in the block
- **WHEN** the author asks for the block
- **THEN** each manual check appears unticked with its setup, action, Check and Log text, not a pointer

### Requirement: Card-moving commands are warned about
`ct.py validate` SHALL warn about a manual step whose `commands` include a CheckThat command that records a result or moves the card, unless the step's notes say it is on purpose.

#### Scenario: Pass in the Run button
- **WHEN** a manual step lists `/ct pass` in its commands
- **THEN** `validate` names the step and the command

### Requirement: Revise a plan after a run
The skill SHALL, when the author has a finished run, read the verify report and its version warnings first, sort each failed, unverified or contradicted step as a plan fault, an addon fault or unknown, edit only plan faults, keep every step id and run the handoff gate again. It SHALL say whether the next run is `/ct rerun failed` (plan unchanged) or a new import (plan changed) and SHALL point to `ct.py diff` for the comparison. It SHALL NOT edit addon code unasked.

#### Scenario: Pattern stricter than the line
- **WHEN** a failed step's hit shows a near match of its pattern
- **THEN** the skill calls it a plan fault and edits the pattern

#### Scenario: Forbidden line present
- **WHEN** a step failed because an `absent` line appeared
- **THEN** the skill calls it an addon fault and edits nothing

#### Scenario: Run of another build
- **WHEN** the report warns that the run used another addon version or plan file
- **THEN** the skill stops and asks for a new run

### Requirement: Main skill text is addon-neutral
The skill's main text SHALL hold the rules that apply to any addon and SHALL point to its reference file for CheckThat's supported-addon list, log sources and version-check recipes.

#### Scenario: Author of another addon
- **WHEN** an author of another addon reads the main skill text
- **THEN** it names no CheckThat internal file or table, and each detail is one pointer away in the reference

### Requirement: Skill scopes a plan before it drafts
Before it drafts or converts a manual test document, the skill SHALL ask what the plan is for: a foundation plan (the release gate) or a feature plan (deep on one feature). It SHALL ask for each candidate check whether a unit test already proves it, give no plan step to logic a unit test proves, base the depth answer on measured coverage, and offer an essential draft first. It SHALL set `purpose` on every plan it drafts.

#### Scenario: Converting a manual document
- **WHEN** the author asks to convert a manual test document
- **THEN** the skill lists which checks a unit test already proves and drafts only the rest

#### Scenario: Purpose first
- **WHEN** the skill reaches the depth question
- **THEN** it asks "foundation or feature?" before it asks about steps, and the drafted plan sets `purpose` to the answer

### Requirement: Skill splits a large scope into a plan set by area
The skill SHALL keep a plan to at most 25 steps and a section to at most 10. It SHALL split a larger feature scope into a plan set by area. Each plan SHALL have its own version, setup and final no-Lua-error step and its own section range, and the plans SHALL be imported and finished one at a time. A plan set by area SHALL NOT be the release gate: a foundation plan is, and feature plans SHALL NOT be "run all before a release" unless the author asks for it.

#### Scenario: Scope too large for one plan
- **WHEN** the essential steps of a feature plan are more than 25
- **THEN** the skill drafts a plan set by area and names the import order

#### Scenario: Release gate
- **WHEN** the author asks for a plan to run before each release
- **THEN** the skill drafts a foundation plan, not a plan set by area

### Requirement: Skill recommends a test-settings mode
The skill SHALL ask whether the plan depends on the addon's settings. When it does, the skill SHALL recommend a test-settings mode in the addon, with a setup step that runs debug on, the test-settings command and `/reload` in that order, and a last step that turns the mode off and asserts the restore line. It SHALL NOT recommend per-step setting commands that overwrite the tester's own settings.

#### Scenario: Plan depends on settings
- **WHEN** the author says a step depends on an addon setting
- **THEN** the skill recommends the test-settings mode and drafts the setup and last steps in that order

### Requirement: Skill drafts a foundation plan from pillars
For a foundation plan the skill SHALL first ask which systems, if they fail, make every feature fail (the pillars) and, for each, the real-game risk that a unit test or the offline block cannot catch. It SHALL draft about one step per pillar (8 to 12 steps), with at least one step that crosses a real threshold end to end and no step that exists only to restore a setting. It SHALL ask which surface the author finds critical and keep a player step for it.

#### Scenario: Pillars before steps
- **WHEN** the author chooses a foundation plan
- **THEN** the skill lists the pillars and their real-game risks, and the author confirms them before any step is drafted

### Requirement: A foundation plan runs on one character
The skill SHALL draft a foundation plan that one stated character can run: any class, any level, no profession, in one stated place, one run per client. A step that needs a class, profession, place, fight or other addon SHALL move to a feature plan, the offline block or a unit test. The preamble SHALL list the character's assumptions and name what leaves the gate and where it goes.

#### Scenario: A step needs a class
- **WHEN** a candidate step of a foundation plan needs a Mage
- **THEN** the skill moves it to a feature plan, the offline block or a unit test and names it in the preamble

### Requirement: Skill reviews a foundation plan for its character and pillars
The skill's review of a foundation plan SHALL list every step the stated character cannot do, every pillar with no step and every pillar with more than about two.

#### Scenario: Review of a foundation plan
- **WHEN** the skill reviews a foundation plan
- **THEN** it reports whether each pillar has one or two steps and whether the stated character can run every step

### Requirement: Skill drafts a feature plan deep on one feature
For a feature plan the skill SHALL interview for the cases of one feature: edge and negative cases, each client, the roles it needs (one plan per role) and combat or instances when the feature touches them. The preamble SHALL say when the plan needs a staged character. The skill SHALL ask whether the plan is retired or kept as a regression plan after the feature ships.

#### Scenario: Feature needs a profession
- **WHEN** the feature needs an engineer
- **THEN** the preamble says so, and the plan is not part of the release gate

### Requirement: Skill writes steps in player language
In both kinds of plan the skill SHALL write action text as one player-language sentence, with commands only in `action.commands` behind Run, and Expect SHALL state what is on screen, never what is logged. The skill SHALL flag any step whose action text or Expect shows a slash command, or whose Expect speaks of the log.

#### Scenario: Command in text
- **WHEN** a drafted step's action text shows `/cvn test sell`
- **THEN** the skill rewrites it as a player sentence and keeps the command behind Run

### Requirement: Skill never cites a step number in player text
The skill SHALL refer to an earlier step in action text, `setup` and `expect` by what the player did there (for example "the vendor you walked to after the first sell question"), never by a step number or id. It SHALL run `validate` with `--addon-src` when the addon source is at hand, so a version step behind the TOC is caught.

#### Scenario: Step depends on an earlier one
- **WHEN** a step needs the window an earlier step opened
- **THEN** its text names that window by what the player did, and `validate` prints no reference warning
