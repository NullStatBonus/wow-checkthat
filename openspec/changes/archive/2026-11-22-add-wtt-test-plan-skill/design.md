# Design

## Context

See proposal.md for motivation. TestThat already ships the format rules (`schema/test-plan.schema.json`, `openspec/specs/test-plan-format/`, `docs/test-plan.md`) and the tools (`tools/wtt.py validate|compile|from-md|collect|report`). The skill reads these and does not copy them. Sibling addons (KeepThat, ClosestVendor, DontDoThat) each log differently, so the skill cannot assume TestThat's log shape.

## Goals / Non-Goals

**Goals:**
- One skill folder that works wherever the author installs it.
- An interview ordered by dependency, a draft, a validate pass and a review.

**Non-Goals:**
- Translating plans. Authors keep one plan per locale.
- A `wtt.py lint` command (#12). The skill uses `validate` plus a by-hand checklist.
- A local ENV file for common paths (#16).
- A `/wtt-plan` command and an OpenSpec hook (#17).
- A shared plugin for sibling repositories (#18).
- Changes to the addon, `wtt.py` or the schema.

## Decisions

- **In-repo source, Makefile install.** The skill source is tracked in `skills/wtt-test-plan/`. `make install-skill` copies it to `~/.claude/skills/` (or `SKILL_DIR`) and writes `.wtt-root` with the checkout path, so the installed copy finds `tools/wtt.py` from any repository. Without that file the skill looks beside itself, then asks. The stamp is install-time only; the broader local config stays in #16. Alternative: a shared plugin now. Rejected: it needs #16 first.
- **Reference, do not copy.** SKILL.md names the format files and tells the agent to read them. This keeps the skill correct as the format changes. Alternative: embed the rules. Rejected: it drifts.
- **Interview order:** locate tools, scope, target addon, output, depth, clients, evidence, human checks, reload and scope of assertions, then draft, validate, review, gaps. Each step unlocks the next. Locale is asked once, for the filename only.
- **Evidence from the addon's own log.** The skill asks for the SavedVariable and format, or reads them from the addon source, and maps log lines to steps. Alternative: require a TestThat-style log. Rejected: the author's addons differ.
- **Review mode is the author's choice.** Accept all, or walk each step.
- **Checklist in `reference.md`.** It holds depth guidance, the by-hand lint checks (missing `commands`, steps lacking an assertion where a log line exists, long plans) and one worked example plan that passes `validate`.
- **Missing evidence becomes an issue offer**, as AGENTS.md requires for deferred work.

## Risks / Trade-offs

- [The skill can drift from the format] → It references files; a test validates the example plan against the current schema.
- [By-hand lint misses what `lint` would catch] → The checklist names the checks; #12 later adds the tool.
- [An agent skips a question] → SKILL.md states which answers are required before drafting.
