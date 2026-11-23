## Why

The debug report and results string open in a custom CheckThat frame. KeepThat, DontDoThat and ClosestVendor open the same text in a standard AceGUI window (title bar, scroll box, status line). Players see two looks for one job.

## What Changes

- `Export.Show` (debug report, results string) opens an AceGUI Frame with a read-only MultiLineEditBox, as the three sibling addons do.
- The editable plan import window (`Export.Prompt`) stays as it is: it needs an Accept button and the Recent plans list.
- If AceGUI is missing, `Export.Show` falls back to the current window.

## Capabilities

### Modified Capabilities
- `debug-tools`: the report window looks like the sibling addons' window.
- `test-runner-ux`: the text window rule covers both windows and keeps the Run button rule.

## Impact

`CheckThat/Debug/Export.lua`, the locale file, tests, README and the manual test plan. Patch release 0.8.3.
