# Tasks

## 1. Layer the text window above the Run button

- [x] 1.1 `tests/test_layers.lua` records each frame's strata and asserts the text window ranks above the Run button and the card. It failed with both at `DIALOG`.
- [x] 1.2 `CheckThat/Debug/Export.lua` sets the window to `FULLSCREEN_DIALOG`. Verify `luajit tests/test_layers.lua` passes and fails again with `DIALOG`.

## 2. Guard the Run button

- [x] 2.1 In `CheckThat/UI/Card.lua`, add a wanted flag: `hideAll` clears it, `setMacro` sets it only when the step has a macro body and the card is shown. Add an `OnShow` hook on the secure button that, out of combat and when the flag is clear, hides the button and logs "run button hidden: nothing to run on this screen (step <id or none>)". Verify with new tests in `tests/test_smoke.lua`: results screen, Start screen and a hidden card re-shown by the driver are hidden again and logged; a step with commands keeps its button; in combat nothing is called on the button. Break each rule once and check its test fails.

## 3. Docs and integration

- [x] 3.1 Add two manual checks to `docs/test-plan.md`: the export window covers the Run button; after finishing the self-test the Run button is gone, also after a fight. Verify numbering stays unique and in order.
- [x] 3.2 Run `make test` and `make check`. Verify both exit 0.
- [ ] 3.3 In game: repeat step 4 and the results screen. Read `/ct log` for the hide line if the button reappears.

## Workflow follow-up

- At archive: sync the delta, bump both TOC versions to 0.5.1 and add the matching `CHANGELOG.md` section.
