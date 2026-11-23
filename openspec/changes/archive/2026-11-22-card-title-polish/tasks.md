# Tasks

## 1. Fit card text and fix the collapsed layout (#41)

- [x] 1.1 Add a card test: long and long-unbroken titles keep the title at card width with one line (collapsed) or two (expanded), and the collapsed card sets a hover tooltip. Break the fix, verify the test fails, restore.
- [x] 1.2 In `CheckThat/UI/Card.lua`, constrain `card.title` and `card.head`, add the tooltip, and anchor the counter left of the collapse button without space for hidden prev/next. Verify the test and `luajit tests/test_smoke.lua` pass.
- [x] 1.3 Add manual checks to `docs/test-plan.md` (long step title, long plan name, minimize the card) and note the limit in README "Good to know". Verify `make test`.

## 2. Run menu control, Import and Clear plan (#40)

- [x] 2.1 Add `App.ClearPlan(runId)` in `CheckThat/Model/App.lua` with tests in `tests/test_app.lua`: ends the run, keeps results exportable, removes plan and recent entry, rejects a stale run id. Break each step, verify failure, restore.
- [x] 2.2 Replace the header label and arrow with the Run control (check Blizzard UI and popular addons first), build the Import, End run, Clear plan menu and `Card.ConfirmClear`, keep the `ConfirmEnd` fallback. Add L[] strings. Verify `tests/test_locale.lua` and `tests/test_layers.lua`.
- [x] 2.3 Update README (Run menu), `docs/listing.md` and `docs/test-plan.md` (menu, Import and Clear plan checks, unique ordered numbers). Verify `tests/test_readme.lua` and `make test`.

## 3. Start and ended screens

- [x] 3.1 Keep the start screen at full width, anchor the first visible button at the left inset; add "Import a plan" to the ended screen when no plan is loaded. Test the button choice with and without a loaded plan, break it, verify failure, restore.
- [x] 3.2 Add a manual check for both screens to `docs/test-plan.md` and update README. Verify `make test`.

## 4. Remove the Reload button

- [x] 4.1 Remove `card.reload` and its layout; reword the reload hints and the share-point text to name `/reload`; change the selftest plan text. Test: no Reload button, hint and results text name `/reload`. Break the text, verify failure, restore.
- [x] 4.2 Update README, `docs/test-plan.md` check 5 and the specs. Verify `make test`.

## 5. Integration

- [x] 5.1 Run `make test` and `make check`; confirm `/ct log` reports the run ended line after Clear plan.

## Workflow follow-up

- Archive the change; addon code changed, so bump both TOC versions (minor), add the CHANGELOG section, then commit.
- Close #40 and #41 with the PR.
