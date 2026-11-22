# Proposal

## Why

Review of the first build found evidence gaps: converted plans report "matched" evidence when only diagnostic assertions ran; log windows misread repeated startup blocks after reload and let "absent" pass with no new lines; the secure button's parent card can break in combat; screenshots, which the user asked for as evidence, were dropped; the Classic Era saved-variable copy skips per-character files.

## What Changes

- Evidence is "matched" only when at least one required assertion exists and all required ones pass; otherwise "diagnostic-only".
- Log windows locate the attempt boundary by position, treat an ambiguous tail as unverified, and require at least one new line before an `absent` assertion can pass.
- The secure button becomes its own top-level frame so the card can move, resize and hide in combat.
- Steps may set `screenshot: true`; the card asks for Print Screen; `collect` copies screenshots taken inside an attempt window into the run's folder and the report lists them.
- Document collecting from the real WTF folder for Classic Era per-character data.

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-evidence`: evidence labelling, log window rules, screenshot collection
- `test-plan-format`: `screenshot` step flag
- `test-runner-ux`: secure button isolation, screenshot prompt

## Impact

`WoWTestThat/Run.lua`, `Evidence.lua`, `UI.lua`, `tools/wtt.py`, schema, README, tests. Sibling addons and the shared copy script are untouched.
