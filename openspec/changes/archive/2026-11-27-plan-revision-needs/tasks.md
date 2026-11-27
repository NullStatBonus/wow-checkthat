# Tasks

- [x] 1.1 `Plan.REV` and the early `needs` check in `Plan.Validate`. Tests in `tests/test_plan.lua`: refused alone before unknown keys, equal revision accepted, absent accepted, bad values refused.
- [x] 1.2 The import message in `App.lua`. Test in `tests/test_app.lua`: the sentence, and nothing stored.
- [x] 1.3 `ct.py`: `PLAN_REV`, `PLAN_NEEDS`, `plan_needs`, the `validate` checks, and the `compile` stamp. Tests: a revision 1 string is unchanged, the stamp is written when a rule matches, `validate` errors, and `PLAN_REV` equals `Plan.REV`.
- [x] 1.4 Schema `needs`, spec delta, `docs/authoring-plans.md`.
- [x] 1.5 Break each behavior once; each test failed.
