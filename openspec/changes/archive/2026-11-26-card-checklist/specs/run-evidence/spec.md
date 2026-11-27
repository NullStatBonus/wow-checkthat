## ADDED Requirements

### Requirement: Action ticks are saved on the attempt
When a step lists its actions, the runner SHALL save on the open attempt which actions the player ticked and when, as `ticks`, keyed by action position. Ticks SHALL survive `/reload`, SHALL stay with the attempt when it gets its verdict, and SHALL NOT change the verdict or the evidence. A new attempt SHALL start with no ticks. `ct report` and `ct show` SHALL show the actions left unticked on a failed, partial or unverified attempt.

#### Scenario: Fail with an action unticked
- **WHEN** the player ticks two of three actions and presses Fail
- **THEN** the attempt records fail, its ticks name the two actions, and the report lists the third as not ticked

#### Scenario: Reload keeps ticks
- **WHEN** the player ticks one action and reloads
- **THEN** the same attempt opens with that action ticked

### Requirement: An async step is judged when the run starts
When a run starts or a step is rerun, the runner SHALL judge each applicable `async` step's required assertions once against the logs as they stand then, with the whole retained log as the window, before any step opens. If all pass, it SHALL record an attempt with verdict pass, claim `auto` and `at: "start"`. Otherwise it SHALL record nothing and the step behaves as an auto step when its turn comes. Judging SHALL open no attempt for the current step, call no entry and start no timer.

#### Scenario: Version reported at login
- **WHEN** the addon reported its `version` fact before the run started
- **THEN** the async version step is passed at start and the card shows the next step

#### Scenario: Evidence not there yet
- **WHEN** an async step's line has not been written at run start
- **THEN** the step stays pending and settles as an auto step on its turn

### Requirement: A requirement can make a step inapplicable
When a step opens, the runner SHALL check its requirements. If a requirement with `unmet: inapplicable` does not hold, the step SHALL be recorded inapplicable with the requirement's text as the reason, the card SHALL move on, and progress SHALL not count it. Unknown class or profession data (no class, no skill lines yet, a collapsed skill header) SHALL leave the step applicable.

#### Scenario: Hunter runs a Mage step
- **WHEN** a Hunter reaches a step that requires `class: [MAGE]` with `unmet: inapplicable`
- **THEN** the step is inapplicable with the requirement's text, and the auto timer never starts

### Requirement: A step that does not apply stays in the run
A step recorded inapplicable by a requirement SHALL keep its place in the run when categories are added or removed. A rerun of its category SHALL check it again, and a step that gets a result SHALL keep no reason.

#### Scenario: Category added
- **WHEN** the tester adds a category after a step was marked inapplicable
- **THEN** the step is still in the run and a rerun of its category reopens it

### Requirement: Async steps keep their whole-log window
A category added during the run SHALL have its async steps judged as at run start. A later attempt of an async step, after Undo or Redo, SHALL read the whole retained log too. A pass at start SHALL NOT hide the plan's preamble or a section's intro.

#### Scenario: Undo of a pass at start
- **WHEN** the tester undoes an async step that passed at start
- **THEN** its next attempt reads the whole log and can pass again

#### Scenario: Preamble after a pass at start
- **WHEN** the only result so far is an async pass at start
- **THEN** the first step the card shows still shows the plan's preamble
