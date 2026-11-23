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
