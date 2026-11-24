# Design

## Context

`Run.Rerun` reopens the steps of one category. The rerun question and message format a count with one sentence for every count.

## Goals / Non-Goals

**Goals:**
- Singular text for one step.
- One command and one menu item for the fix-and-retest loop.

**Non-Goals:**
- Rerunning partial or skipped steps. A partial result is a decision of the tester.
- A button on the card. The Categories row menu and the command are enough.

## Decisions

1. **`failed` is a reserved name, not a flag.** `/ct rerun failed` beside `/ct rerun <category>` needs no new syntax. Validation rejects the id in the tool and on import, so a plan cannot make the name ambiguous. Alternative: let a category win. Rejected: the same word would mean two things.
2. **One function.** `Run.Rerun` takes the reserved name and picks steps by verdict instead of by category. The history, retry and current-step handling stay shared.
3. **Singular by two whole sentences.** One for 1, one for the other counts, both through `L[...]`. The reopen message becomes "Reopened N steps: <name>." so it reads right for a category title and for the failed set.
4. **The menu row shows on every row** when a failed or unverified step exists, since it does not depend on the row's category.

## Risks / Trade-offs

- [A saved plan that already uses `failed` as an id no longer validates] → no plan in the repository uses it; the message names the fix.
