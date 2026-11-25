# Tasks

## 1. Macro text and sync

- [x] 1.1 `Plan.MacroAllowed` already refuses a body over 255 characters, so `App.MacroText` needs no change. Add a case to `tests/test_app.lua` that pins the limit. Break the check, see the test fail, restore it.
- [x] 1.2 Split `Card.MakeMacro` into `Card.SyncMacro(silent)` and the `/ct macro` wrapper. Keep the "never overwrite a changed macro" rule. `tests/test_combat.lua` still passes for `/ct macro`.
- [x] 1.3 Call `SyncMacro` from `Card.Refresh` when `profile.macroFollow` is on. Skip when the body is unchanged. Out of combat, log `macro set <step id>`. In combat, make no edit (the refresh after combat writes once). Tests in `tests/test_combat.lua`: step change rewrites the macro, no change gives no log line, two changes in combat give one rewrite after `PLAYER_REGEN_ENABLED`, an edited macro stays untouched, the setting off changes nothing, and no body holds a result command for any step of a fixture plan.
- [x] 1.4 Show one card line when the step has commands but no macro body. Show none for a step with no commands. Add test cases and wrap the text in `L["..."]`; `tests/test_locale.lua` passes.

## 2. Setting

- [x] 2.1 Add `macroFollow = false` to `Core/Defaults.lua`. Add the toggle and help text to `Options/Options.lua` per `DESIGN.md`. Log `macroFollow on/off`. Turning it on calls `SyncMacro`. `tests/test_options.lua` validates the tree.
- [x] 2.2 Add `macroFollow` to the debug report. Check with `/ct log` in the replay or harness test.

## 3. Docs, plan and release

- [x] 3.1 Update README (setting, "Good to know": macro holds commands only, one macro, 255 characters), `docs/features.md` (behavior and log lines), `docs/listing.md`. `make test` passes (README and docs checks included).
- [x] 3.2 Add a short check to `docs/test-plan.md`: bind `CT` and Pass, play three steps with keys only. One action, one `Check:` line, `Log:` line `macro set <step id>`. Keep section numbers in order.
- [x] 3.3 Run `make test` and `make check`.

## Workflow follow-up

- Offer the ct-test-plan skill once after the tasks are done (setting and player-visible behavior changed).
- At archive: bump both TOC versions (minor, addon code changed), add the `CHANGELOG.md` section, comment on and close #103, then tag as in `docs/publishing.md`.
