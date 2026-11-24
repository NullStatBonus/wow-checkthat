# Design

## Context

`ct.py` is the non-interactive core that skills and CI call. A read-only viewer is planned (issue #83). Codex reviewed this step and the viewer layout.

## Goals / Non-Goals

**Goals:**
- Narrow the report to what needs attention, and follow a step's detail by name.
- A refresh loop the viewer can reuse (`status_watch`).

**Non-Goals:**
- The terminal viewer: issue #83.

## Decisions

1. **Failed means fail and unverified.** The same steps `--strict` and JUnit count, by `classify`.
2. **`show` reuses `report_text`** with a step filter, so the output format has one source. For one step, every attempt shows, with its stacks.
3. **Run names.** An exact id, or a part that names exactly one run. Otherwise exit 2 with the choices.
4. **Watch.** Redraws on a terminal and prints a time line when redirected. It returns the last status exit code. Ctrl-C ends it.
