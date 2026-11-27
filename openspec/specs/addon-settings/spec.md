# addon-settings Specification

## Purpose
The standalone settings window, its pages, controls and profile scope, shared with the sibling addons.

## Requirements

### Requirement: Standalone settings window follows the shared design
The addon SHALL register AceConfig options in an AceGUI standalone window with a tree, default size 600 x 460, title "CheckThat", resizable and scrollable. Pages SHALL be Home, Plans, Appearance, Advanced and About, each openable directly, each with a heading, a purpose statement of one or two short sentences, and sections for tasks. The same pages SHALL be registered under the game's Settings window.

#### Scenario: Open a page directly
- **WHEN** the player runs `/ct settings plans`
- **THEN** the window opens on Plans with its purpose visible

### Requirement: Controls follow the shared vocabulary
Booleans SHALL be checkboxes, bounded numbers sliders at 1.5 Ace widths, colors native pickers, actions buttons. Body text SHALL be neutral #DDDDDD and secondary text grey. Disabled controls SHALL keep their values.

#### Scenario: Appearance slider
- **WHEN** the player sets card scale
- **THEN** the card rescales immediately and the value is saved in the profile

### Requirement: Settings scope is shared by default
Settings SHALL use the shared Default profile. A checkbox in Advanced SHALL switch to a character profile after confirmation, copying nothing and keeping both profiles. Run data (plans, runs, log) SHALL be account-wide.

#### Scenario: Switch scope
- **WHEN** the player selects separate settings and confirms
- **THEN** the character profile is used and the shared profile keeps its values

### Requirement: Appearance options
Appearance SHALL offer card scale (50 to 200), background opacity (0 to 100), text opacity (0 to 100), lock position, and reset position. Persistent visuals SHALL default to a pure black background, draw nothing at zero opacity, and keep text dimmable.

#### Scenario: Zero opacity
- **WHEN** background opacity is 0
- **THEN** no fill or border is drawn

### Requirement: Home lists past runs
The Home page SHALL list stored runs in a choice list, newest first, each with date, plan title, character and counts of pass, fail and open steps. Each entry SHALL start with the date and time. Open, Export and Delete SHALL act on the chosen run. Delete SHALL name the run and ask for confirmation. Open on an ended run SHALL show it on the card and SHALL leave the character's current run unchanged. Open on an unfinished run of the character SHALL make it the current run, SHALL start again the attempt it left open, and SHALL ask for confirmation while another unfinished run has the card. Open SHALL be unavailable for an unfinished run of another character. The list and its buttons SHALL NOT draw when no runs are stored.

#### Scenario: Reopen an older run
- **WHEN** the player chooses Open on an ended run
- **THEN** the checklist window shows that run, read-only, and the current run is unchanged

#### Scenario: Slider drag
- **WHEN** the player drags Runs to keep through a low value
- **THEN** no run is deleted until the next run starts

#### Scenario: Export an older run
- **WHEN** the player chooses Export on a run
- **THEN** the text window shows that run's export string

#### Scenario: Unfinished run of another character
- **WHEN** the chosen run has not ended and belongs to another character
- **THEN** Open is unavailable and Export and Delete stay available

#### Scenario: Delete the current run
- **WHEN** the player deletes the current run and confirms
- **THEN** the run is gone and the checklist shows the start screen

### Requirement: Run limit setting
The Advanced page SHALL offer a run limit from 5 to 100 runs, with a default of 20, shared by all profiles. Pruning SHALL happen when a run starts and SHALL NOT happen while the setting changes. The debug report SHALL print its value.

#### Scenario: Report shows the limit
- **WHEN** the player runs /ct log
- **THEN** the report names the run limit and the number of stored runs and plans

### Requirement: Open run asks first while a run is active
Open run SHALL ask the player to accept before it opens a run when this character has an unfinished current run that is not the run chosen. The question SHALL say whether the current run leaves the checklist or stays. Without an active run, or for the current run itself, Open run SHALL ask nothing.

#### Scenario: Viewing an ended run
- **WHEN** the player chooses Open run for an ended run while a run is active
- **THEN** a question says the current run stays, and the run opens only after the player accepts

#### Scenario: Replacing a run
- **WHEN** the player chooses Open run for an unfinished run while another run is active
- **THEN** a question says the current run leaves the checklist, and nothing opens until the player accepts

#### Scenario: Nothing active
- **WHEN** this character has no unfinished current run
- **THEN** Open run opens the run without a question

### Requirement: Past runs mark ended runs
Each Past runs entry for an ended run SHALL end with `, ended` after the counts. An unfinished run SHALL carry no such marker.

#### Scenario: Ended and open rows
- **WHEN** Home lists one ended run and one unfinished run
- **THEN** only the ended run's entry ends with `, ended`

### Requirement: Macro follow setting
The settings page SHALL offer "Keep the CT macro on the current step". It SHALL be off by default and stored in the profile. Its help text SHALL say that the macro runs commands only and that the tester still presses a result key. The debug report SHALL show its value as `macroFollow`. Changing it SHALL log `macroFollow on` or `macroFollow off`.

#### Scenario: Default
- **WHEN** the addon loads for the first time
- **THEN** the setting is off and the debug report shows `macroFollow` as off

#### Scenario: Turned on
- **WHEN** the tester turns the setting on during a run, out of combat
- **THEN** the CT macro is set to the current step's commands at once

### Requirement: Saved data carries its shape revision
The addon SHALL keep the shape revision of the saved global table in `dbRev`. A table without it SHALL count as revision 0, the shape of 0.21.0, and SHALL get revision 1 at load with no other change. Each migration SHALL take one revision to the next and SHALL run once. A revision above the one this version writes SHALL be left unchanged.

#### Scenario: Data from 0.21.0
- **WHEN** the addon loads saved data with no `dbRev`
- **THEN** `dbRev` is 1 and every other key is as it was

#### Scenario: Data from a newer version
- **WHEN** the addon loads saved data whose `dbRev` is above its own
- **THEN** `dbRev` keeps its value and the debug log says it was left as it is

### Requirement: Result sounds setting
Appearance SHALL offer a "Play result sounds" checkbox, on by default. `/ct set card.sound on|off` SHALL change it, and the debug report SHALL show its value. When it is off, CheckThat SHALL play and log no result sound; `/ct sound` previews SHALL still play.

#### Scenario: Sounds off
- **WHEN** the player turns Play result sounds off and a step passes
- **THEN** no sound plays and the log has no `sound` line for that step
