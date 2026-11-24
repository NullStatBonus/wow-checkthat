# Design

## Context

`Errors.Record` writes one line per error. `Errors.Hook` sets the handler at run start and on a category trigger.

## Goals / Non-Goals

**Goals:**
- Attribute errors, keep one stack per step, notice a taken handler.

**Non-Goals:**
- Showing the stack in `tools/ct.py report`: the report reads runs, not the saved error lists. Tracked in issue #78.
- Measuring the cost of `debugstack` inside the handler. It needs the Era and Forever clients; test plan check 9 does it.
- Keeping locals. They can hold private data.

## Decisions

1. **The tag sits after the counter.** `[Addon]` keeps the time and counter first, so lines stay different and ordered. A plan checks `pattern` with the brackets escaped. Lines CheckThat adds itself say `[CheckThat]`.
2. **The stack goes to a second list.** One line per stack, same time and counter as the error line, so the error list stays one line per error and absence checks are unchanged. Only the first error of each step keeps one (`Errors.StepStarted` from `App.Begin`), cut to 600 characters, 20 kept. A failed read does not use up the step's stack.
3. **BugGrabber's own stack.** With the slot blocked, the stack of the new BugGrabber entry is used (no capture).
4. **Watch.** `Errors.Watch` runs from the card refresh and before a result is judged. It re-hooks at most once a second and logs the first five takes only.
5. **The amber line only appears on steps that read the error list**, found through the plan's log source (`CheckThatDB`, `global.errors`).

## Risks / Trade-offs

- [A library inside an addon carries the addon's path] → documented.
- [`debugstack` cost in the handler] → `pcall`, once per step, check 9 measures it.
