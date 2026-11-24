# Proposal

## Why

Plans for KeepThat, DontDoThat and ClosestVendor declare no `cap`, so absence checks and exact counts on their debug logs can stay unverified when the last lines are alike (issue #76). No page says where CheckThat fits beside wowless and BugGrabber (issue #72).

## What Changes

- The sample and full plans for the four addons declare the cap of the addon's debug log (300, 500, 300, 300). `tools/ct.py` adds it when it builds a plan from a test-plan file. A test keeps plans and tool in step.
- A new page `docs/tools-guide.md` compares the tools and lists the optional "better with" addons. The README, the listing and the debug-logging guide link to it.
- A test checks that the TOC files declare no required dependency.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-authoring`: caps in sample plans, and the tools guide.

## Impact

- Files: `plans/`, `tools/ct.py`, `tools/test_ct.py`, `tests/test_layers.lua`, `docs/`, `README.md`.
- No file under `CheckThat/` changes. No version bump, no changelog entry, no tag.
