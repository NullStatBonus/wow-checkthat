# Spec Delta

## MODIFIED Requirements

### Requirement: Standalone settings window follows the shared design
The addon SHALL register AceConfig options in an AceGUI standalone window with a tree, default size 600 x 460, title "CheckThat", resizable and scrollable. Pages SHALL be Home, Plans, Appearance, Advanced and About, each openable directly, each with a heading, a purpose statement of one or two short sentences, and sections for tasks. The same pages SHALL be registered under the game's Settings window.

#### Scenario: Open a page directly
- **WHEN** the player runs `/ct settings plans`
- **THEN** the window opens on Plans with its purpose visible
