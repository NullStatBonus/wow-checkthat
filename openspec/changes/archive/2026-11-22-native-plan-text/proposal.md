# Proposal

## Why

Converted plans carried Markdown (backticks and bold). The game does not render Markdown, so testers saw literal `` and ** marks.

## What Changes

- Plan text shown by the game uses native color codes: gold for emphasis, light blue for commands. Titles and section names are plain.
- The converter produces native text. The validator in Python and in the addon rejects backticks and ** in display fields.
- Existing plans are converted.

## Capabilities

### Modified Capabilities
- `test-plan-format`: display text formatting

## Impact

`tools/wtt.py`, `Model/Plan.lua`, `plans/`, `schema` docs, AGENTS.md, tests.
