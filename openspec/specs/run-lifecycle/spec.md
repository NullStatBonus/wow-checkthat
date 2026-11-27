# run-lifecycle Specification

## Purpose
Let an addon learn when a run of its plan starts or stops being the open run, and read which run is open, so it can set up and restore its own test state.

## Requirements

### Requirement: Register for run events
CheckThat SHALL expose `CheckThat.OnRun(addonName, fn)`. It SHALL return true when it stores `fn` and false otherwise. It SHALL refuse an invalid addon name and a value that is not a function. It SHALL never raise an error to its caller. A second registration for the same addon SHALL replace the first. `CheckThat.API_VERSION` SHALL be 3.

#### Scenario: Valid registration
- **WHEN** an addon calls `CheckThat.OnRun("KeepThat", fn)`
- **THEN** the call returns true

#### Scenario: Bad arguments
- **WHEN** the name is invalid or `fn` is not a function
- **THEN** the call returns false and raises no error

### Requirement: End event
CheckThat SHALL call `fn("end", info)` once each time the open run of the current character stops being the open run, when the run's plan names the registered addon. The `info` table SHALL hold `plan` (the plan name), `digest` (the plan digest), `runId` and `reason`. The reason SHALL be `ended` when the tester ends the run or clears the plan, `replaced` when another run takes its place, and `deleted` when the run is deleted while open. CheckThat SHALL NOT call `end` for a run that was already ended or was not the open run. A `/reload` SHALL NOT fire `end`.

#### Scenario: Tester ends the run
- **WHEN** the tester ends the open run of a KeepThat plan
- **THEN** the KeepThat callback receives `"end"` with reason `ended`

#### Scenario: Another run replaces it
- **WHEN** the tester starts or opens a different unfinished run
- **THEN** the callback of the first run's addon receives `"end"` with reason `replaced`

#### Scenario: Deleted while open
- **WHEN** the tester deletes the open run
- **THEN** the callback receives `"end"` with reason `deleted`

#### Scenario: Reload
- **WHEN** the game reloads with a run open
- **THEN** no `end` call is made

### Requirement: Start event
CheckThat SHALL call `fn("start", info)` when a run of a plan that names the registered addon becomes the open run of the current character: a new start, or a resume of an unfinished run. When an addon registers while such a run is already open, CheckThat SHALL call `start` for it once at registration. `start` MAY fire again for the same run after a reload. The callback of a replaced run SHALL receive `end` before the new run's `start`.

#### Scenario: New run
- **WHEN** the tester starts a plan for KeepThat
- **THEN** the KeepThat callback receives `"start"` with the plan name and digest

#### Scenario: Late registration
- **WHEN** a KeepThat run is open and KeepThat registers after login
- **THEN** the callback receives `"start"` once, at registration

#### Scenario: Other addon
- **WHEN** a run's plan names another addon
- **THEN** the callback is not called

### Requirement: Safe delivery
CheckThat SHALL call the callback with `pcall`, after it has saved the run state. A raised error SHALL be written to the debug log, and to the error list while a run is open, and SHALL NOT change the run or stop the other callbacks. CheckThat SHALL pass `info` as a copy that the addon can change without effect.

#### Scenario: Callback throws on end
- **WHEN** the callback raises an error on `end`
- **THEN** the run is still ended and the error is in the debug log

#### Scenario: Callback throws on start
- **WHEN** the callback raises an error on `start`
- **THEN** the run stays open and the error is in the error list

### Requirement: Read the open run
CheckThat SHALL expose `CheckThat.ActiveRun(addonName)`. It SHALL return the plan name of the current character's open run when that run's plan names the addon, and nil otherwise. It SHALL never raise an error.

#### Scenario: No run open
- **WHEN** no run is open for the addon
- **THEN** the call returns nil

### Requirement: A reload marks the character's open run
After a reload the runner SHALL mark the open attempt of the character's open run as reloaded and SHALL print the resume lines for that run. It SHALL NOT mark or report a run that is only shown on the card, such as an ended run opened from Past runs.

#### Scenario: Past run on the card
- **WHEN** the card shows an ended run while another run has an open attempt, and the player reloads
- **THEN** the open run's attempt is marked as reloaded, chat names the open run, and the ended run is not reported as resumed

#### Scenario: No open run
- **WHEN** the character has no open run after a reload
- **THEN** no resume line is printed and no attempt is marked

### Requirement: Pruned runs are named in chat
When starting a run deletes runs beyond Runs to keep, CheckThat SHALL say in chat which runs it deleted, whether or not they were exported.

#### Scenario: Over the limit
- **WHEN** a sixth run starts with Runs to keep at 5
- **THEN** chat says "Deleted the oldest run (<plan>) to keep 5."
