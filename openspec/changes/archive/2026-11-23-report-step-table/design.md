# Design

## Context

`report_text` in `tools/ct.py` looped over `r["order"]` and printed a line for a passing step only when a screenshot or a CheckThat-recorded mark existed. The evidence state of a step is in `rec["attempts"][-1]["outcomes"]` (each `{result, why}`).

## Goals / Non-Goals

**Goals:**
- Every step visible in the report with its evidence state.

**Non-Goals:**
- Changing the in-game report or the plan format.
- Assertions for the ClosestVendor sample (issue #13, change `report-and-sample-assertions`).

## Decisions

1. **Evidence state values.** From the last attempt's outcomes: `met` when all outcomes pass, `bad` when any fail, `missing` when any is unverified or has no result, `none` when there are no assertions. Alternative: one count "2/3". Rejected: the state names match what the card shows.
2. **Table layout.** A plain text table placed before the detail lines, one row per step, columns separated by two spaces. Steps outside the plan order follow, sorted. Alternative: Markdown table. Rejected: the report is read in a terminal.

## Risks / Trade-offs

- [Wide tables for long step ids] → truncate the note column to 40 characters and fold line breaks in notes.
