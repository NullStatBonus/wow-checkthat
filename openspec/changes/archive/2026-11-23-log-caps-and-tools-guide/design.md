# Design

## Context

`cap` on a log source lets a log below its cap count as never rolled, so where a step began is certain.

## Goals / Non-Goals

**Goals:**
- Caps read from the sibling addons' source, with file and line in `docs/contracts.md`.
- A guide that cites each tool page with the date it was read.

**Non-Goals:**
- Reading DontDoThat's bound from its saved variable. The addon has no caller of `Log.SetMax`, so the bound is 500 unless the saved file is edited. A plan reads no bound from a saved variable today.
- The WoWUnit bridge (issue #61).

## Decisions

1. **DontDoThat uses its default, 500.** The contracts page names the risk: a bound set lower makes the cap overstate what the log holds.
2. **CheckThat's own plans get cap 300**, the value of `Log.MAX`.
3. **One test ties `LOGS` in `ct.py` to every plan** with a debug log of the same addon.

## Risks / Trade-offs

- [A sibling addon changes its bound] → the contracts page names file and line to re-check.
- [Tool facts change] → the guide is dated and cites its pages.
