# Design

## Context

`Model/Evidence.lua` has no game globals, so it runs under luajit. `tools/sv2json.lua` already loads `Model/Json.lua` the same way. `tests/replay.lua` already plays a compiled plan in the fake client and finds a step that judges its own result line, a step that never settles and a step the card shows twice; the skill does not run it yet. `tools/verify_fixture.py` replays only verdicts the game already made.

## Goals / Non-Goals

**Goals:**
- Fail a build when a plan's log or fact check drifts from a fixture.
- Catch the #102 plan faults that need no game: own-line assertions, a missing version check, a stale bundle.
- Put the existing replay into the skill's review.

**Non-Goals:**
- Running the addon's own code (#94, #96, #97).
- Replacing in-game runs.
- A version fact for addons other than CheckThat: https://github.com/NullStatBonus/wow-checkthat/issues/105.
- Log line when Undo reopens a step (#100), coverage (#93) and run diff (#92).

## Decisions

- **Driver:** a luajit script `tools/replay_sv.lua` loads the plan and fixture, builds `env` from the decoded saved variables, and calls `Evidence.Check` with empty snapshots so the whole log is the window. `ct.py replay` calls it and writes JUnit through the existing `report_junit` shape. Alternative: port the matching to Python. Rejected: two matchers would drift.
- **Not judged offline:** the driver marks a check unjudged when `Evidence.Check` needs a snapshot position (`exactly`, `max`, attempt-scope `absent`) or when `Probe` returns nil. Unjudged counts as a skipped test case, never a pass. A required unjudged check does not fail the run, but the report counts it.
- **Fixture age and digest:** read the capture time and plan digest from the fixture metadata; warn on a digest mismatch.
- **Lint:** add the own-line rule and the version warning to `validate` in `tools/ct.py`, next to the other step checks. The own-line match uses `[ct] step <id> ` as a prefix of the asserted text, and a `pattern` is tested against that sample line.
- **Bundle check:** the skill compares `$CT/VERSION` to the checkout's TOC version when both exist. This is skill text, not code.

## Risks / Trade-offs

- Without a window, count checks mean less offline; the report says so per check.
- Fixtures go stale; the digest warning is the guard.
- A `pattern` own-line test can miss odd regexes; the replay catches the rest at run time.
