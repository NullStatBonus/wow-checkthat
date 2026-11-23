## MODIFIED Requirements

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

## ADDED Requirements

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
