# Design

## Context

`tools/entry_runner.lua` builds the fake client, loads the TOC files once and runs the steps. `tests/harness.lua` holds the fake client (`H.stubClient`), the TOC reader and the nil-read recorder. The offline level (D7 of 2026-11-25-offline-client-fidelity) gates every stricter check.

## Goals / Non-Goals

**Goals:** the game's order of load, saved variables and login events. A `/reload` that drops all Lua state but the saved variables. A fresh load for each group of steps.

**Non-Goals:**
- A separate Lua state or process for each load. The fresh load restores the global table and the standard library tables in one process. A change an addon makes elsewhere, such as in a metatable of a type, can still leak, and the docs say so.
- Load-on-demand addons, LoadWith, and the order between several addons.
- The event bus and the virtual clock (#150).
- VARIABLES_LOADED and SPELLS_CHANGED. The wiki says neither has a fixed place in the order.
- Measuring the logout order and the PLAYER_ENTERING_WORLD arguments in game (#163).
- A fresh load that also resets tables that existed before the run, such as a LibStub a test loaded first (#164).

## Decisions

### D1. Level 3 turns on the load order

Level 3 changes what happens before step 1: ADDON_LOADED fires, `IsLoggedIn()` is false during load, and the saved-variable names are nil while the files run. A plan that already fires ADDON_LOADED in an `event` step would see it twice. So the load order is level 3, and a block without it keeps its result. `reload`, `groups` and `savedVariables` are refused below level 3, by the schema and by the runner, which tests call directly.

### D2. Saved variables follow the game

Source: warcraft.wiki.gg, "AddOn loading process" and "Saving variables between game sessions".
- The TOC files run first. Then the saved-variables file runs, and then ADDON_LOADED fires. With `## LoadSavedVariablesFirst: 1` the saved variables load before the files.
- The saved-variables file assigns only the names it holds. So a value the addon sets at file scope survives on a first login, and a saved value replaces it.
- The runner sets each declared name to nil before the files run. A value left from an earlier load cannot leak in.
- A `savedVariables` name the TOC does not declare fails the load step, because the game would not restore it.
- On reload the runner copies each declared name as the game writes it: strings, numbers, booleans and tables, with string, number and boolean keys. Functions, userdata and threads are dropped. Two references to one table come back as two tables. A reference back to a table the copy is already inside is dropped. A name whose value is nil is not written, so a fresh load keeps its file-scope value.
- The copy is a deep Lua copy, not `tools/sv2json.lua`: JSON would turn a number key into a string key.

### D3. Events and their arguments

- Payloads follow the generated API documentation of both clients (`Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua`).
- Login: ADDON_LOADED (folder name, and `containsBindings`: whether the folder holds `Bindings.xml`), then PLAYER_LOGIN, then PLAYER_ENTERING_WORLD (true, false).
- Reload: PLAYER_LEAVING_WORLD, PLAYER_LOGOUT and ADDONS_UNLOADING (`closingClient` false). Then the fresh load, the copied saved variables, and the same login events with PLAYER_ENTERING_WORLD (false, true).
- An event that no frame registered is not an error. A handler that throws fails the load step or the reload step, with the event's name.
- `IsLoggedIn()` is false from the start of a load until PLAYER_LOGIN.

### D4. One fresh-load helper

`H.snapshot()` records the keys and values of `_G` and of `string`, `table`, `math`, `bit` and `coroutine`. It returns `restore()`, which removes added keys and puts the old values back. The runner takes the snapshot once, before the first `stubClient`. Before each later load it:
1. stops the nil-read hook;
2. restores the snapshot;
3. builds a new `stubClient`, so `st.secure` holds only the game's names;
4. puts back its `CreateFrame` wrapper, the `CheckThat` stub with new entries, the mocks, the hidden globals and the nil-read hook.

Restoring the snapshot removes `LibStub`, so libraries register again, as after a real reload. At level 3 the runner also restores the snapshot when the run ends, so a second run in the same process starts clean. Levels 1 and 2 leave the fake client in place, as they always did. The snapshot is shallow: a `LibStub` that existed before the run keeps what the first load registered, and a reload then fails with "already exists". `ct.py` starts a new process for each plan, so only a test that loads libraries before `Runner.run` meets this. The compiled chunks are reused, because calling a chunk again makes new locals and upvalues. Nil reads from every load are merged.

### D5. Groups

- `groups` is a list of `{label, mocks, savedVariables, steps}`, and a block holds either `steps` or `groups`.
- A group's mocks are added over the block's mocks, and the group's value wins for the same API.
- A group without `savedVariables` uses the block's. It never inherits from the group before it.
- Mock counts start at zero for each group and continue across a reload inside it.
- Each result carries `group`, so `ct.py` names steps `offline.G.N`. A block without groups keeps the ids `offline.N`.

### D6. Old blocks keep their results

At levels 1 and 2 an event still reaches a frame that a handler created while it ran (`ipairs`). After the run, `CreateFrame` is still the stub client's and `CheckThat` is what `prepare` left. The runner refuses a block that holds both `steps` and `groups`, or empty `groups`, as the schema does.

### D7. Output

The JSON result keeps every key it has. A block without groups produces the same steps, ids and labels as before. The level warning now suggests `level: 3`. The text of a warning on stderr is not a format the tools read.

## Risks / Trade-offs

- An in-process fresh load is weaker than a new Lua state (see Non-Goals). The snapshot covers what addons usually touch.
- The wiki marks the logout events with {{fact}}. The order follows the wiki, and `docs/contracts.md` records it as source-reviewed until CTProbe measures it (#163).
