# Proposal

## Why

The test-plan skill turns log lines into required checks, but nothing says what a log line worth asserting on looks like. For an addon with no debug log, the skill only offers a player check or an issue. Authors get no help building the log that would make their plan stronger.

## What Changes

- Add `docs/debug-logging.md`: the debug-log pattern the sample addons share, what makes a line worth asserting on, how each assertion kind uses it, and real example lines from KeepThat, DontDoThat, ClosestVendor and TestThat.
- Ship the guide in the `make install-skill` bundle.
- The skill reads the guide in its evidence step. When the addon has no debug log, the skill says so once, recommends adding one, and points to the guide.
- The skill drafts such a plan with player checks and marks the steps that become log assertions once the log exists.
- The skill's gap step offers one issue for the log facility plus one issue per needed line, each naming the steps it unlocks.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-authoring`: guidance for addons without a debug log, and a shipped debug-logging guide.

## Impact

- `docs/debug-logging.md` (new), `skills/wtt-test-plan/SKILL.md`, `reference.md`, `Makefile` (`BUNDLE`), `tools/test_wtt.py`, `README.md`.
- No addon, schema or saved-data change.
