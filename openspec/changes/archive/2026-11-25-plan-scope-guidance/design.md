## Context

Issues #162 and #167 came from retrofitting an addon with CheckThat. Both ask for guidance more than for new machinery.

## Goals / Non-Goals

**Goals:**
- Push back on plan size where authors look: the `validate` output and the skill interview.
- Document plan sets by area and the test-settings pattern.

**Non-Goals:**
- A run-level setup and teardown in the plan format (#167 item 3). It needs addon code (`Model/Plan.lua`); the run start and end callback in #171 covers an addon that must undo its test settings when a run is abandoned.
- Spec-requirement coverage across unit tests and plans together in `ct coverage` (#162). That is #143.
- A scope of `run` for the final no-Lua-error step (#161).

## Decisions

- **Count after `cases` expand.** The card shows each case as a step, and the limit is about what a tester runs. A step with many cases warns, which is the intent.
- **Warn, never fail.** The thresholds are advice. A fixture or a runner self-test can stay long, and old plans keep their result. `PLAN_STEPS_MAX` and `SECTION_STEPS_MAX` are named constants.
- **Repository plans that warn stay as they are.** `plans/full/keepthat.yaml` (31 steps), `plans/selftest.yaml` (one section of 16) and the picker fixture (26) are documented as getting the warning. The skill's example plans are tested to stay below it.
- **The test-settings mode belongs to the addon.** The allow list holds the slash prefix, so a subcommand such as `testsettings` needs no CheckThat change.

## Risks / Trade-offs

- A legitimate long plan now prints a warning on each validate. → It is one line, and the docs say when it is expected.
