# Design

## Context

Issue #94 is a spike: measure, then build, defer or drop each part. The offline half needs no game client and no change to the addon or the plan format, so it can be built and proven now. The in-game half needs Era and Forever clients and a protected-frame probe, so it stays unmeasured here.

## Goals / Non-Goals

**Goals:**
- Prove offline: mocks reach code that captured a global at load; entries can be called with literal arguments; returns, throws and call counts can be checked; fake events can be fired; mocks are restored afterward.
- Record what the existing fake client lacked, so sibling addons know the reuse cost.
- Measure how often the four addons capture game globals at file scope.

**Non-Goals (each filed as an issue):**
- Plan-format fields for mocks, entry calls and per-category setup (schema, `Plan.lua`, `ct.py`, spec together): #96.
- The in-game `CheckThat.Entry` API and an `auto` step that calls entries (`API_VERSION` rises; needs a version bump): #97.
- In-game mocks: wait for the taint probe on Era and Forever: #98.
- A login self-check setting: #99.

## Decisions

1. **Own spec file, not a plan.** The runner reads JSON: `toc`, `mocks`, `steps`. This keeps the spike out of the format specs.
2. **Reuse `tests/harness.lua`.** The runner calls `H.stubClient()` and adds only what it lacks (a recorded `RegisterEvent`, a stub `CheckThat` global). The additions are the reuse measurement.
3. **Mocks before load.** Mocks are set before the TOC loads, so a file-scope capture sees them. A `mockAfterLoad` flag shows the in-game limit: an override set later does not reach a captured local.
4. **Data only.** Arguments and expected values are JSON literals. An entry name that was not registered fails the step. No code comes from the spec.
5. **Evidence says mocked.** Every step result carries `mocked`, and the run lists each mock with its call count, so an offline pass is never read as a real-client pass.
6. **Restore.** Mocked globals return to their earlier values when the run ends.
