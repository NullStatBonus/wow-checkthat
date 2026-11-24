# Proposal

## Why

A failed or unverified attempt saves the outcome of each check, not the log lines that arrived while the step was open. The reviewer must find the place in a debug log that may have rolled over (issue #68).

## What Changes

- When an attempt records fail or unverified, it keeps the first 20 new lines of each log its step checks, each cut to 200 characters, as `excerpt`.
- `tools/ct.py report` prints the lines under the attempt. The `ct-verify` skill knows the field.

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-evidence`: attempts keep an excerpt.

## Impact

- Code: `Model/Evidence.lua` (`Evidence.Excerpt`), `Model/Run.lua`, `tools/ct.py`, `skills/ct-verify/SKILL.md`. Tests, docs, version 0.13.0.
- The results string stays version 1: the field is added.
