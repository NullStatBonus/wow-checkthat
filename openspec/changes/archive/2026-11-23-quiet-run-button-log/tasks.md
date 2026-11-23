# Tasks

## 1. Quiet log

- [x] 1.1 Log the hidden Run button once for each screen in `Card.EnsureSecure`. Verify: `luajit tests/test_smoke.lua` has a case for five shows in a row and one for the next step.
- [x] 1.2 Break it (log every time), see the test fail, restore.
- [x] 1.3 Update `docs/test-plan.md` check 9, record the measured rate in `docs/contracts.md`, add the 0.8.0 Fixed line. Verify: `make test` and `make check`.

## Workflow follow-up

- 0.8.0 is not released, so it keeps its number and gets one more Fixed line.
