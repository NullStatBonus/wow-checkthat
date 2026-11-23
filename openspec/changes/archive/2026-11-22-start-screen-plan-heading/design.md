# Design

## Context

`Card.Refresh` has a start-screen branch. It sets `card.title` to "Ready to test" and `card.context` to one sentence built from the plan title and step count. The 2-line fit and full-title tooltip (`card.titleHit`) already exist for step titles. A Codex UX review chose this layout: title as heading, status line under it.

## Goals / Non-Goals

**Goals:**
- Plan title is the heading; count, status and instruction share the line under it.
- Singular and plural step counts both read correctly and translate whole.

**Non-Goals:**
- No change to the "CheckThat" header, the Run menu or the footer buttons.
- No change to the run, ended or collapsed screens.
- Dropping "Select Start run" (issue #42 bullet) is out: the owner asked to keep the wording.

## Decisions

- **Whole-sentence keys, chosen by count.** `L["1 step. Ready to test. Select Start run."]` and `L["%d steps. Ready to test. Select Start run."]`. Translators reorder freely; no concatenation (`tests/test_locale.lua`). Alternative: a plural helper. Rejected: the repo has none.
- **Heading uses `card.title`.** Same two-line fit as step titles; reuse `card.titleHit` with the full title for the tooltip. Alternative: a new fontstring. Rejected: duplicates layout code.
- **No plan:** heading `L["No plan yet"]`, body `L["Select Import a plan and paste a plan string."]`. Replaces the one-sentence key `No plan yet. Select Import a plan and paste a plan string.`.
- Remove the unused keys `Ready to test` (as heading) and `Plan ready: %s (%d steps). Select Start run.`.

## Risks / Trade-offs

- [Plan title empty or very long] → fit() caps at two lines; tooltip shows the full text; plan validation already requires a title, so no empty-title case is handled.
- [Stale locale strings] → `test_locale` fails on keys with no use; remove them in the same change.
