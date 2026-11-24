# Design

## Context

`report_text` printed detail only for steps whose last verdict did not pass. Stacks and errors live in `CheckThatDB.global.errors` and `errorStacks`, outside a run. Codex reviewed the plan and the design.

## Goals / Non-Goals

**Goals:**
- Evidence health in one command, readable by a person and a script.
- One classification of a step for every report format and `--strict`.

**Non-Goals:**
- Wowless in CI (#26): needs a Docker spike first. Stays open.
- WoWUnit facts (#61): needs a probe of what WoWUnit exposes. Stays open.
- Stacks per attempt in json and junit, evidence of a reopened step, a stack for a slash-opened attempt: issue #81.
- A complete retry history: Undo removes an attempt, so the newest revision cannot promise one.

## Decisions

1. **One rule.** `classify` maps a step to pass, partial, fail, unverified or skipped. A pass or partial claim whose last required outcome failed is a fail, and one with a required outcome without a result is unverified. Json, junit and `--strict` all use it.
2. **JUnit.** A suite for each run and category, a case for each step. Fail and unverified are `failure` (type tells them apart); no `error`. Partial passes. Pending, skip, deselected and inapplicable are skipped with a reason.
3. **Stacks.** Matched to an attempt by the time in the `<time>.<counter>` key against the attempt window. Time has whole-second precision, so a key that fits two attempts is labelled. Md shows stacks; json and junit need `--stacks` because stacks can hold private paths.
4. **Status judges the evidence, not the test.** Exit 1 for no runs, an unreadable revision, a logged conflict, or a size over 80% of the limit. `report --strict` judges the test. Sizes are estimates from the saved run.
5. **Conflicts.** A saved run holds open-attempt `snapshots` that an export strips. Same-revision comparison ignores them. Real conflicts and decode failures go to `problems.log`.
6. **Excerpt budget.** 60 000 bytes of excerpt lines for a run; the attempt with the oldest finish time loses its excerpt first. The attempt record stays.
7. **Stack for each attempt.** `App.Begin` asks for a stack only when the attempt count grew.

## Risks / Trade-offs

- [A logged conflict keeps status at exit 1] → the message says to delete `problems.log` after review.
- [A stack matched by time can name the wrong attempt] → labelled when it fits two.
