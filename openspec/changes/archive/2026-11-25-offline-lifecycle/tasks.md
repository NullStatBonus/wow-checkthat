## 1. Fresh load

- [x] 1.1 `H.snapshot()` in tests/harness.lua, with a test that added globals and library keys are removed
- [x] 1.2 `H.tocMeta(path)`: SavedVariables, SavedVariablesPerCharacter, LoadSavedVariablesFirst

## 2. Runner level 3

- [x] 2.1 `Runner.LEVEL = 3`, refuse `reload`, `groups` and `savedVariables` below level 3
- [x] 2.2 Load order: names nil during load, assign `savedVariables`, events, `IsLoggedIn`
- [x] 2.3 `reload` step: logout events, copy as the game saves, fresh load, login events (false, true)
- [x] 2.4 `groups`: fresh load for each group, merged mocks, `group` on each result
- [x] 2.5 Tests: file-scope write lost, first-login default kept, reload round trip, two groups with opposite mocks, a flag set in one group absent in the next, old block unchanged (ADDON_LOADED event step fires once, `IsLoggedIn` true)

## 3. Plan format and ct.py

- [x] 3.1 Schema: level 3, `savedVariables`, `groups`, `reload`, refused below level 3
- [x] 3.2 `offline_plan`: ids `offline.G.N` and group labels, and the warning names level 3
- [x] 3.3 Python tests

## 4. CheckThat round trip

- [x] 4.1 tests/test_lifecycle.lua: CheckThat starts a run, reloads through the harness, and the run is still current

## 5. Docs

- [x] 5.1 docs/authoring-plans.md, skills/ct-test-plan/SKILL.md (`level: 3`), docs/contracts.md note
