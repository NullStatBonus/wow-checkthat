## MODIFIED Requirements

### Requirement: Standalone settings window follows the shared design
The addon SHALL register AceConfig options in an AceGUI standalone window with a tree, default size 600 x 460, title "CheckThat", resizable and scrollable. Pages SHALL be Home, Plans, Appearance, Advanced, About and Profiles, each openable directly, each with a heading, a purpose statement of one or two short sentences, and sections for tasks. The same pages SHALL be registered under the game's Settings window.

#### Scenario: Open a page directly
- **WHEN** the player runs `/ct settings plans`
- **THEN** the window opens on Plans with its purpose visible

#### Scenario: Open Profiles
- **WHEN** the player runs `/ct settings profiles`
- **THEN** the window opens on Profiles

### Requirement: Settings scope is shared by default
Settings SHALL use the shared Default profile until the player chooses another profile on the Profiles page. Run data (plans, runs, log) SHALL be account-wide and SHALL NOT change with the profile.

#### Scenario: Switch scope
- **WHEN** the player chooses another profile in Manage profiles
- **THEN** that profile is used, nothing is copied, and the profile left keeps its values

#### Scenario: New character
- **WHEN** a character loads CheckThat for the first time
- **THEN** it uses the Default profile

## ADDED Requirements

### Requirement: Profiles page
The Profiles page SHALL name the profile in use and SHALL hold the standard AceDBOptions-3.0 profile control, inline, to choose, create, copy, reset and delete profiles. When the library is missing, the page SHALL show its purpose and the profile line only.

#### Scenario: Choose another profile
- **WHEN** the player chooses another existing profile in Manage profiles
- **THEN** its settings apply at once and the page names it

### Requirement: A profile switch is named
Each login SHALL print "Profile in use: <name>." A switch to another profile SHALL print "Profile changed. Profile in use: <name>." in chat and SHALL log `profile changed to <name>`. A switch, a copy and a reset SHALL keep the value of the debug switch. `/ct status` SHALL name the profile in use, and the debug report SHALL show it as `profile`.

#### Scenario: Debug kept
- **WHEN** debug recording is on and the player switches profile
- **THEN** chat names the new profile and debug recording stays on

#### Scenario: Report
- **WHEN** the player opens the debug report
- **THEN** it shows `profile = <name>`
