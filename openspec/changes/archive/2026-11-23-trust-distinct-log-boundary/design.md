# Design

## Context

`Evidence.NewLines` finds the lines written since a step opened. The snapshot holds the log length and the last 12 lines. On a full ring the length stays 300, so the tail is found by search. Review found that a tail of identical lines can match new lines and hide one between them, so such a boundary was marked inexact. A measured run showed this marks every boundary inexact on a full log.

## Goals / Non-Goals

**Goals:**
- Absence checks pass on a full log with a distinctive tail.

**Non-Goals:**
- Timestamps in the snapshot. Lines are compared as text.

## Decisions

1. **Distinct lines decide.** The boundary is exact when at least half of the tail lines differ and the tail matches once. A repeated pattern of two or three lines is the remaining risk; the uniqueness check and the 12 line length make a coincidence unlikely. Alternative: store the entry times. Rejected: the snapshot format and every log source would change.

## Risks / Trade-offs

- [A periodic log could match a window that is not the boundary] → needs a tail that repeats yet appears once; measured logs hold varied lines.
