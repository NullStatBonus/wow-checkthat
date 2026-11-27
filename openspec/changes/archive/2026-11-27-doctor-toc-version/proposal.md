## Why

Issue #253 (split from #31): a second checkout can overwrite the installed addon, and a plan then runs against the wrong version (a 0.17 plan once ran on 0.16.0). `ct.py doctor` did not compare the installed version with the checkout.

## What Changes

- `installed_version_lines`: for each client folder doctor reports, read `Interface/AddOns/CheckThat/CheckThat_Vanilla.toc` (else the first `CheckThat_*.toc`) and compare its `## Version:` with the checkout's. Different: a warning line naming both and the folder. Same: one line. None installed: a note.
- Docs: `harvesting.md`, README.

## Capabilities

### Modified Capabilities
- `run-verification`: doctor compares the installed version with the checkout.

## Impact

`tools/ct.py`, `tools/test_ct.py`, docs. Doctor's exit code is unchanged. Tools only; no version bump.
