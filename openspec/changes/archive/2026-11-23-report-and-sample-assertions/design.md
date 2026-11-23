# Design

## Context

`plans/closestvendor.yaml` has one assertion (cv.s2.1, "test command: sell"). Other steps carry reviewer notes only. A scan of every ClosestVendor saved variable in the shared saved folder found 300 log lines in one character and none of the expected test or question lines.

## Goals / Non-Goals

**Goals:**
- Sample assertions that match real, recorded lines only.

**Non-Goals:**
- Guessing log lines from ClosestVendor source. The plan's own reviewer note already records one such case that did not match.
- The report table (issue #10, change `report-step-table`).

## Decisions

1. **Sample data first.** Task order: collect a fresh run, record each line in `docs/contracts.md`, then write assertions. Without new data, #13 stays open.

## Risks / Trade-offs

- [New run data may still lack the lines] → leave #13 open with a comment naming the missing lines.

## Open Questions

- Which exact ClosestVendor steps get assertions depends on the lines the new run produces.
