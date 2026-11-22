# Design

## Context

Sample addons already share a pattern (off by default, `debug on|off`, `log`, a bounded ring of `[area] message` lines) but it is written down only in `docs/contracts.md` (formats) and the `debug-tools` spec (TestThat only). See proposal.md.

## Goals / Non-Goals

**Goals:**
- One guide the skill and addon authors can cite.
- Examples taken from the real addons, so authors copy proven shapes.

**Non-Goals:**
- No new schema field, no `validate` rule about logs, no change to `LOGS` in `wtt.py`.
- No library or shared logging code for addons.
- No change to how TestThat reads logs.

## Decisions

- **Guide lives in `docs/debug-logging.md`**, not `reference.md`. It also serves authors who never run the skill. It joins `BUNDLE` so the installed skill still reads it with no checkout. Alternative: inline it in `reference.md`; rejected, because it hides the guide from non-skill readers.
- **Facts and advice stay apart.** The pattern and formats cite `contracts.md`, the `debug-tools` spec and the sample addons. Advice on line wording is labeled as guidance.
- **Examples quote source lines** read from the sibling addon repos on 2026-11-22. They show shape, not a stable API, so the guide says they may drift.
- **Skill points, does not duplicate.** SKILL.md carries the branch logic and links to the guide for content.
- **Guide is not in the root-detection file list.** An older bundle without it must still count as a root; the skill reads it only if present and otherwise says it is missing.

## Risks / Trade-offs

- [Quoted lines drift as addons change] → guide says "as of" the review date and favors the shape over exact text.
- [Advice over-prescribes] → advice sits in its own section, marked as guidance.
