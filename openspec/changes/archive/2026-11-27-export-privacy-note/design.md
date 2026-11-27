## Decisions

- **The status line, not a dialog.** The AceGUI frame already has a status line under the box with the copy hint. The note goes before the hint in it, and in the plain window's hint. Nothing new to click.
- **Optional parameter.** `Export.Show` keeps its callers: the debug report passes no note and shows the hint alone.

## Non-Goals

- An export without the character. It would be a new choice in the export flow, not needed for the note; the issue leaves it separate.
