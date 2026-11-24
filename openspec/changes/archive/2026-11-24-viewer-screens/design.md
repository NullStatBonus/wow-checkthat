# Design

## Context

Codex reviewed the design before it was built.

## Goals / Non-Goals

**Goals:**
- Triage on 40 columns first; more columns from 76.
- Color only helps: words and marks say the same.

**Non-Goals:**
- Tabs, trees, column sorting, a search box: they add interaction without helping the triage path.
- A progress bar: the fraction says it in less width.

## Decisions

1. **Count each run once.** Fail wins over unverified. The rest are "no flags", not "OK": a run with only pending steps is not clean.
2. **Done over eligible.** `resolved/eligible` by the rule `status_data` uses; a dash when no step applies.
3. **Chips follow the evidence.** The tracker's category rule is fed with the classified result of each step, so a pass the evidence overturned makes the chip red.
4. **Two column sets.** Under 76 columns: result, id (and done for runs). From 76: the rest. A resize switches them and keeps the selection.
5. **One line each.** The strip and the problem line do not wrap; a long one ends with an ellipsis.
6. **Cells stay styled.** `fill` passes styled Text through; evidence is never markup.
