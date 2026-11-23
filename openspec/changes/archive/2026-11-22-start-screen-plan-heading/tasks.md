# Tasks

## 1. Start screen

- [x] 1.1 Add tests in `tests/test_card.lua`: with a plan, `card.title.text` is the plan title and `card.context.text` is "N steps. Ready to test. Select Start run."; one step reads "1 step."; no plan shows "No plan yet" and the import line. Break the code, see them fail, restore.
- [x] 1.2 Change the start-screen branch of `Card.Refresh` in `CheckThat/UI/Card.lua`: plan title heading with the full-title tooltip when cut, count line from the two new keys, no-plan heading and body. Verify: `luajit tests/test_card.lua` passes.
- [x] 1.3 Replace the old locale keys with the new ones. Verify: `luajit tests/test_locale.lua` passes.
- [x] 1.4 Update the stale "Ready to test" and "Plan ready" text in `docs/test-plan.md` (sections 3.2 and 3.13), `README.md` and `docs/listing.md` where they describe the start screen. Verify: `make test` passes.

## 2. Verify

- [x] 2.1 Run `make test` and `make check`.

## Workflow follow-up

- Archive, bump the version (addon code changed), write the changelog, then commit. Close issue #42.
