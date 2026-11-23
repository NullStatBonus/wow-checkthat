## Context

KeepThat `Debug/Export.lua`, DontDoThat `Debug/Export.lua` and ClosestVendor `Report.lua` share one pattern: AceGUI `Frame` (layout Fill, status text "Press Ctrl+A to select everything, then Ctrl+C to copy."), one `MultiLineEditBox` with no button, text reverted on edit, all selected on open. CheckThat already embeds the Frame and MultiLineEditBox widgets.

## Decisions

- Use the same pattern in `Export.Show`. Reuse the sibling code as is. Do not build a shared library for four addons.
- Keep `Export.Prompt` and its frame. An editable box with Accept and a dropdown is not a report window.
- Fall back to `Export.Prompt` read-only when `AceGUI-3.0` or its Frame is missing.
- AceGUI's Frame uses strata FULLSCREEN_DIALOG, above the card's DIALOG strata, so the Run button rule holds. A test checks it.

## Non-Goals

- Restyling the import window.
- A shared window module across addons.
