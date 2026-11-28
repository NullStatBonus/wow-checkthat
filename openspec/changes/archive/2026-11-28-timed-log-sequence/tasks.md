# Tasks

## 1. Evidence

- [x] 1.1 `Evidence.NewLines` returns the index of the first new line as a third value.
- [x] 1.2 `Evidence.CheckTimedSequence`: each item's matching lines, a chain from the last item back, and the first position after each one for the gap.
- [x] 1.3 `Evidence.CheckSequence` takes that path only when an item gives `within`, and slices the window's times.
- [x] 1.4 Tests: a gap in time, a gap too long, an untimed source, a three-item chain, a later line of the same item, the step's own window, and the detail. Break the chain once and see the tests fail.

## 2. Validation

- [x] 2.1 `Plan.WITHIN_MAX` and `Plan.REV = 3`; a `within` on the first item, a `within` that is not a whole number, and one out of range are refused.
- [x] 2.2 The schema: `within` in `$defs/matcher`, a whole number from 1 to 600.
- [x] 2.3 `tools/ct.py`: `PLAN_REV = 3`, the `within` rule in `PLAN_NEEDS`, and the same validation messages.
- [x] 2.4 Tests in `tests/test_plan.lua` and `tools/test_ct.py`, including `needs` and the parity of the two validators.

## 3. Docs

- [x] 3.1 `docs/authoring-plans.md`: how to write it, an example, the limits and the plan revision.
- [x] 3.2 `docs/features.md`: how it reads, and the "stopped at item N" reason.
- [x] 3.3 `docs/test-plan.md` check 4.16, `README.md` feature line, `CHANGELOG.md`, both TOC versions.
- [x] 3.4 `make test` and `make check`.
