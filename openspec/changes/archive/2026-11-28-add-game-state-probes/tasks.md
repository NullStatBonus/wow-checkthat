# Tasks

## 1. Reads

- [x] 1.1 `Adapter.lua`: the `issecretvalue` guard in `call`, and `callName(space, name, ...)` for an API table with the older global as the fallback.
- [x] 1.2 `Adapter.Env()`: `GetMoney` in the wrapped list; `env.ContainerFreeSlots(bag)` and `env.ItemCount(id)`, each client's spelling chosen by whether the function exists.
- [x] 1.3 Test: a missing read, a raising read, a secret value, the API table and the older global. Break the guard once and see the test fail.

## 2. Probes

- [x] 2.1 `Plan.PROBES`: `money`, `bag-free-slots`, `item-count`, `frame-text`.
- [x] 2.2 `Evidence.Probe`: one branch per probe; nil for a missing function, a raising call, a non-number answer, a non-text frame answer, a missing `id` and an unreadable bag in the sum.
- [x] 2.3 `Evidence`, `Plan.lua`, schema and `tc.py`: the optional `id` and `bag` fields, with validation (`item-count` needs a numeric `id`; `bag` is a whole number).
- [x] 2.4 Tests: value, missing function and an unknown answer for each probe; validation of the two fields. Break each read once and see its test fail.

## 3. What the plan reads

- [x] 3.1 `App.PlanReads`: a `frame-text` check's name is listed, a `frame-shown` one is not.
- [x] 3.2 Test in `tests/test_app.lua`.

## 4. Docs

- [x] 4.1 `docs/authoring-plans.md`: the probe table, an example and the limits.
- [x] 4.2 `docs/features.md`: how a state probe reads and when it is unverified; the start screen line.
- [x] 4.3 `docs/contracts.md`: what each client provides for the four reads, from the census manifests.
- [x] 4.4 `README.md` feature line and `docs/results-format.md` privacy line.
- [x] 4.5 `make test` and `make check`.

## Workflow follow-up

- Run a plan with each probe in game on Era and Forever; read the results and record the in-game answers in `docs/contracts.md`.
- `bind-location` and `in-combat` (the rest of #67) stay open for a later change.
