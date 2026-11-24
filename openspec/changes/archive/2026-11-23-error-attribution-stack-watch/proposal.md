# Proposal

## Why

A plan that must show "no error from my addon" cannot tell whose error it saw (issue #63). A failed "no Lua error" step shows no place (issue #64). An addon that takes the error handler during a run hides errors until the next category start (issue #70).

## What Changes

- Each recorded error line names the addon from its file path: `<time>.<n> [<addon>] <message>`.
- The first error of a step keeps a short call stack in `global.errorStacks`. `/ct log` shows the newest.
- CheckThat sets its handler again when another addon replaces it (at most once a second). An amber line on the card says when nothing can see errors.

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-evidence`: the error list names the addon and keeps stacks.
- `debug-tools`: the report shows the newest stack.
- `test-runner-ux`: the card warns when CheckThat cannot see errors.

## Impact

- Code: `Model/Errors.lua`, `Core/Adapter.lua` (`Adapter.Stack`), `Model/App.lua`, `UI/Card.lua`, `Debug/Log.lua`. Tests, docs, version 0.12.0.
- BugGrabber stays optional.
