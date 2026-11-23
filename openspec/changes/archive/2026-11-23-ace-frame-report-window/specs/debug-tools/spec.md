## MODIFIED Requirements

### Requirement: Copyable report
`/ct log` SHALL open a window with a selectable report: addon version, client, build, every saved setting, the current run status, failures, then the recorded lines. The window SHALL be the standard AceGUI frame with a scrolling read-only text box, the same as KeepThat, DontDoThat and ClosestVendor.

#### Scenario: Copy
- **WHEN** the report opens
- **THEN** its text is selected-all ready for Ctrl+C

#### Scenario: Same window as the sibling addons
- **WHEN** the report opens
- **THEN** it shows a title bar, the status line "Press Ctrl+A to select everything, then Ctrl+C to copy." and a text box that ignores typing

#### Scenario: AceGUI missing
- **WHEN** the AceGUI frame is not available
- **THEN** the report opens in the plain CheckThat text window instead
