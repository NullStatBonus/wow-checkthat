# Design

## Context

Codex reviewed the first draft. It asked for the detail to come from the check itself, and it set the privacy and size rules.

## Goals / Non-Goals

**Goals:**
- Any tool can name the lines that decided a check from the saved run alone.
- The data is a documented contract, with a schema.

**Non-Goals:**
- Joining the plan to older runs. An older run has only `why`.
- Showing a check's detail in the in-game card.

## Decisions

1. **The check returns the detail.** `Evidence.Check` takes `wantDetail` and returns a third value built from the lines it judged. Preview does not ask. A second read at verdict time could differ from the one that judged (the log can change between), so there is none.
2. **Which outcomes.** Every outcome that is not a pass, also in a passing attempt. Passing outcomes keep none of it.
3. **Positions.** `n` is 1-based inside the window the check judged (the lines after the step opened, or the whole log for session scope). Hit text is its own copy, so it does not depend on the 20-line excerpt.
4. **Which hits.** Per kind, so the line named is the one that decided: first matches for a forbidden line; first line past the bound for a count; last reached item for a sequence; the final fact, a violating fact or the last rejected facts for a fact check.
5. **Size.** The 60 000 byte budget counts excerpt and hit text. A trimmed attempt keeps the rule, counts and reason, and its checks are marked `trimmed`.
6. **Privacy.** Reports leave line text, values and the full rule (it holds the plan's literals, which can be a log line) out of JSON and JUnit unless `--lines`; they show the `shape`, the rule with literals left out. Markdown always shows all of it, as it shows the excerpt.
6a. **Cost.** A check that passes builds no detail, so a passing presence check keeps its early exit.
7. **Schema.** Unknown keys are allowed. A test validates a run the addon wrote.
8. **Version.** 0.14.0.

## Risks / Trade-offs

- [Saved variables grow] → at most 3 hits of 200 characters for each failed check, inside the existing budget.
- [A hit may not be in the excerpt] → it carries its own text.
