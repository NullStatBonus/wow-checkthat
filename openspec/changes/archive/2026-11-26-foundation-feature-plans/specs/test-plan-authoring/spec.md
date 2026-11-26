## MODIFIED Requirements

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

## ADDED Requirements

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
