# Design

## Context

`PlanSkill.missing_commands` in `tools/test_wtt.py` already finds the gap, but only the skill's example plan runs through it. `validate()` returns errors only; the CLI prints `error:` lines. See proposal.md.

## Goals / Non-Goals

**Goals:**
- One shared check in `tools/wtt.py`, reported as warnings by `validate` and `from-md`.

**Non-Goals:**
- No new schema field, no addon change, no error-level failure.
- `compile` stays silent about warnings.
- No auto-fix that rewrites `commands`.

## Decisions

- **New `warnings(plan)` function** returns `(step_id, command)` tuples; `validate()` keeps returning errors only. Alternative: change `validate` to return both. Rejected, because callers and tests rely on `[]` meaning valid.
- **Move the helper's regex and prefix match as is**, so behavior matches what the skill test already checks. The test class calls `wtt.warnings` instead of its own copy.
- **Skip `copy-slash` steps.** Their text is the command and already gets a copy box; `plans/selftest.yaml` has two.
- **Warning, not error** (as issue #12 asks). Some text may mention a command without wanting a Run button.
- **`from-md` needs no new extraction.** It already lifts backticked commands into `commands`. It prints `warnings()` for plain commands it missed.

## Risks / Trade-offs

- [Shipped plans may trigger warnings] → fix them in the same change; `test_shipped_plans_validate` also asserts no warnings.
- [False positives for prose such as "/reload" in an explanation] → warning only; author may ignore.
