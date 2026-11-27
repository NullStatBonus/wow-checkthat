## Why

Issue #246: a first user from CurseForge or Wago has no plan to run. The README's first plan is `build/selftest.ct`, which needs Python and LuaJIT to build, and the addon ships no plan. The card said "Select Import a plan and paste a plan string." with nothing to paste.

## What Changes

- The addon ships the compiled `plans/selftest.yaml` in a new data file, `Model/BuiltIn.lua` (both TOCs). `make builtin` writes it. `tools/test_ct.py` fails when it differs from the compiled plan.
- The import window is titled "Import a plan". Its dropdown is "Choose a plan": "CheckThat self-test (built-in)" first, then the recent plans. A recent entry for the same plan is left out.
- Choosing the self-test imports it at once through `App.ImportPlan`, the same path as a pasted string. The string never shows in the box.
- The paste box hint reads "Paste a plan string that starts with !CT1!".
- The empty card says "Select Import a plan to try the built-in self-test or paste a plan string."
- Nothing else offers the self-test: no popup, no login message, no first-run prompt, no Home entry.

## Capabilities

### Modified Capabilities
- `test-runner-ux`: the import screen pins the built-in self-test; the empty start screen points to it.

## Impact

`CheckThat/Model/BuiltIn.lua` (new, both TOCs), `Model/App.lua` (`App.ImportChoices`, `App.BuiltInString`), `UI/Card.lua`, `Debug/Export.lua`, `Makefile`, tests, docs. No saved data changes. The version bump is held per the release hold.
