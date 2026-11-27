## ADDED Requirements

### Requirement: The import window uses the AceGUI frame
When AceGUI is loaded, the import window SHALL open in the AceGUI frame with the "Choose a plan" dropdown and the Import button. The plain window SHALL open only when AceGUI is missing or fails, and the debug log SHALL say why.

#### Scenario: AceGUI loaded
- **WHEN** the player opens Import a plan
- **THEN** the AceGUI frame opens and the log has no `import window: plain window` line
