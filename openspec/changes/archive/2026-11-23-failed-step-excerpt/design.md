# Design

## Context

`Run.Verdict` judges the checks with the attempt's saved log positions, then drops the positions.

## Goals / Non-Goals

**Goals:**
- Keep the evidence of a failure with the run.

**Non-Goals:**
- Excerpts for passes. They add size and no review value.
- Excerpts of `session` scope checks, which read the whole log.
- Anonymizing lines. Debug lines may hold private data; the docs say to check before sharing.

## Decisions

1. **First 20 lines, 200 characters each, per source.** Fixed limits keep saved variables and the results string small. The first lines come right after the step opened, where the cause usually is. A reviewer sees the cut in the line count. Alternative: the last 20. Rejected: a flood after the cause would push it out.
2. **Reuse `Evidence.NewLines`.** The same boundary rules apply: a rolled log with no exact boundary adds nothing, so an excerpt never holds lines from before the step.
3. **`pcall` around the read.** A broken log source must never stop a result.

## Risks / Trade-offs

- [Saved variables grow] → at most 20 × 200 characters per source for each failed attempt.
