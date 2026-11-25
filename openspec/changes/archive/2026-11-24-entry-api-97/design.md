# Design

## Context

`Facts.API()` is the public table; `CheckThat.Report` is the pattern. See proposal.md. The plan step already settles itself from log and fact lines, so the call result reuses them.

## Goals / Non-Goals

**Goals:** register entries, call them from an auto step, report the outcome as a fact.

**Non-Goals:**
- Mocks in game: wait for the taint probe (#98). The probe is added to CTProbe; its result is not measured yet.
- A `returns` or `throws` field on the step. The fact line and the existing fact checks already say it.
- The login self-check (#99).

## Decisions

- **Outcome as a fact.** No new assertion kind; plans, replay (`ct.py replay`) and reports read it as before.
- **Call at attempt open**, after `Run.Begin`, so the fact falls in the step's window.
- **`Model/Entries.lua`** owns the registry; the combat state comes through `env.InCombatLockdown` (Adapter's guarded read).
- **Registration closed while a run is open**, so a plan cannot make an addon add code mid-run.

## Risks / Trade-offs

- Calling an addon function from CheckThat's insecure code may taint. An entry that touches protected frames is the author's risk; #98 measures it.
- An addon cannot be forced to expose entries. Unregistered code stays untested.
