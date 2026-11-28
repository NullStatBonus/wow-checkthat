# Tasks

## 1. Runner

- [x] 1.1 Load `spec.hooks` once (loadfile, must return a table), check each `hook` step's name before load, and gate `hooks` and `hook` steps at level 5. Test: a missing file, a file that raises, no table, an unknown name, a hook step without a file, level 4.
- [x] 1.2 The `hook` step: build `ctx` (`ns`, `client`, `level`, `fire`, `combat`, `advance`, `mockCalls`, `eq`, `same`), unhide globals while it runs, judge `returns` and `throws`. Test each `ctx` field, a reload changing `ctx.ns`, and `io` reachable from a hook but not from addon code.

## 2. Plan format and ct.py

- [x] 2.1 Schema: `offline.hooks` and the `hook` step (label, hook, args, returns or throws), level 5 in steps and groups. Test in `tools/test_ct.py`.
- [x] 2.2 `offline_plan` resolves `hooks` inside the addons folder and refuses a path that leaves it. Test both, and a run through `ct offline`.

## 3. Docs

- [x] 3.1 `docs/authoring-plans.md`: a "Lua hooks (level 5 and later)" part with an example and the `ctx` reference, marked additive only. `skills/ct-test-plan/SKILL.md`: when to use a hook step. `docs/skills.md`: the hooks `ctx` is the public part; `tests/` stays internal.
- [x] 3.2 Run `make test` and `make check`; confirm no file under `CheckThat/` changed.
- [x] 3.3 Fix the review: hidden globals for addon code a hook runs, all hidden globals for the hook (host values taken before level 5), the hooks file's nil reads, the event check in `ctx.fire`, the addon's own hidden-name values kept, a schema rule that a hook step needs `hooks`, the file loaded only for a load that goes ahead, `ctx.same` on a cyclic table, and the docs.
