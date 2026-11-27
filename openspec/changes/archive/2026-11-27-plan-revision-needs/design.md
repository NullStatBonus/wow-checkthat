## Decisions

- **Refuse first and alone.** The revision check runs before any other validation and returns only its own error. Keys a newer plan holds would otherwise produce errors that hide the reason.
- **Stamp only when needed.** `compile` writes `needs` only when the plan uses a later addition, or when the author gave one. A revision 1 plan compiles byte for byte as before. Its digest does not change, and neither do the runs keyed by it.
- **Rules in the tools, not in the plan.** Authors do not write `needs`. `PLAN_NEEDS` maps each later addition to its revision. Each future plan-format change raises `Plan.REV` and `PLAN_REV` together and adds one rule. A test fails when the two constants differ.
- **`ct: 1` stays.** `ct` is the major format. `needs` is the minor revision inside it, which mirrors `Run.MAJOR` and `Run.FORMAT_REV` for run records.

## Non-Goals

- Rules for the existing keys. Everything up to 0.21.0 is revision 1.
