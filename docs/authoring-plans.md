# Write a plan

A plan is a YAML file in `plans/` that follows `schema/test-plan.schema.json`. CheckThat imports it as a `!CT1!` string.

## Steps

1. **Write or convert.** Draft a plan from an existing manual test document:

   ```
   .venv/bin/python tools/ct.py from-md ../wow-keepthat/docs/test-plan.md --addon KeepThat -o plans/keepthat.yaml
   ```

   Or ask the [plan skill](skills.md) to interview you and draft it.
2. **Validate.** `.venv/bin/python tools/ct.py validate plans/<addon>.yaml`. It fails on a step that asserts its own result line, and warns when the first step does not check the version.
3. **Compile.** `make build` writes `build/*.ct`. Compile one plan with `.venv/bin/python tools/ct.py compile plans/<name>.yaml -o build/<name>.ct`.
4. **Import and run.** In game, `/ct import`, paste, then `/ct start <addon>`.

The plan format is specified in `openspec/specs/test-plan-format/`. Rules for automatic steps are in the [feature reference](features.md#automatic-steps). Screenshots are in [Collect evidence](harvesting.md#screenshots).

## Plans in this repository

- `plans/<addon>.yaml` are short samples (4 to 7 steps each) that `make build` compiles. ClosestVendor keeps its own plan in its own repository, so none is kept here. `plans/selftest.yaml` is the runner's own plan, not a sample. It has 15 steps (16 after `cases` expand) and uses every kind of check: log lines, fact operators, counts, state probes, the quiet error source and `cases`.
- `plans/full/` holds the full conversions of the sibling test plans. The tests validate them and `make build` does not compile them. Compile one with `tools/ct.py compile plans/full/<name>.yaml -o build/<name>-full.ct`.
- `plans/checkthat-0.16.yaml` tests Remove from run and the result keys on its own run, in forever-camelot only.
- `plans/checkthat-0.16-picker.yaml` tests the category picker and the paged Home list. It needs `plans/checkthat-picker-fixture.yaml`, a ClosestVendor plan with 26 categories that is only for looking at the start screen.
- `plans/checkthat-openrun.owner.yaml` and `plans/checkthat-openrun.viewer.yaml` are a plan set for two characters on one account. The owner leaves a run open. The viewer checks that Open run is unavailable for it and that Export run and Delete run work. Run the owner plan first. Read both runs back with the verify skill.

## First live run

Run `build/selftest.ct` first. It exercises the card, copy boxes, the Run button, log evidence, reload resume, every fact and state operator, counts and Lua error capture with no sibling addon.

1. `make build`, then copy `CheckThat/` to `Interface/AddOns/`.
2. In game, `/ct import` with the contents of `build/selftest.ct`, then `/ct start CheckThat`.
3. Do the steps, then `/ct export` and `/reload`.
4. [Collect the evidence](harvesting.md).

Next, try `build/dontdothat.ct`.

## Replay a plan

Before a tester runs a plan, play it in the fake client: `ct.py replay-flow plans/<addon>.yaml [--hooks hooks.lua]` (it works from the installed skill, needs `luajit`; in a checkout `make build` then `luajit tests/replay_plan.lua build/<plan>.ct [hooks.lua]` does the same). It starts a run and does what a tester does at each step: it writes the debug lines and facts the step's checks need, lets an automatic step settle, and presses Pass. It runs once for each client (Forever and Classic Era) and fails when a step ran on neither. It prints each step's result and exits 1 on a problem:

- a step asserts the line its own result writes (`[ct] step <its id> ...`). CheckThat judges the result first, so the result stays unverified and the card does not advance;
- an automatic step never settles, or a step has no result after its action;
- a step never gets reached.

It warns when the card shows a step a second time, because the step's text must cover both visits. A hooks file (`tests/replay/checkthat-0.17.lua` is an example) says which result to press (`verdict`), which steps the card shows again on purpose (`revisits`), and what to do for a step that moves the card, such as Undo, a click on a step row or Remove from run (`action`). `tests/test_replay.lua` replays the 0.17 plan on every `make test`. It checks the plan's flow only. What the addon does is for the game.

For a plan about another addon, the replay writes the lines the checks look for into the plan's own log source (a literal line, a pattern's shortest match, each item of a sequence), marks an automatic step's `/reload` as done and prints `evidence assumed`, so most plans need no hooks file. It warns `evidence not derived` for a check it cannot write (a back-reference in a pattern); give that step a hooks `action`. Because the replay writes those lines itself, a pass says nothing about whether the addon logs them. `ct.py lines plans/<addon>.yaml --addon-src <addon folder>` checks that each asserted line and fact key appears in the addon's Lua source (a line built at run time matches on its tag and words, or on any run of its words of at least 8 characters, such as `test command` for `"test command: " .. kind` or `items found` for `"%d items found"`, and the same holds for `equals`, `contains` and the plain part of a `pattern`; `--strict` exits 1 on a miss). The offline block and `replay --sv` are the checks that prove it without the game.

## Check a plan against saved variables

`.venv/bin/python tools/ct.py replay plans/<addon>.yaml --sv <fixture dir>` judges the plan's log and fact checks against saved variables, with no game. It needs `luajit`. The fixture dir holds the SavedVariables `*.lua` files from a real run, with personal names removed, and may hold `fixture.json`: `{"recorded": "YYYY-MM-DD", "digest": "<plan digest>"}`. The command prints JUnit and exits 1 when a required check fails.

- The whole log is the window, as with `scope: session`. A typo in `contains` or `pattern`, a line that is not in the log, and a forbidden line that is in the log all fail.
- A check that needs the step's own window cannot pass here. `absent`, `exactly`, `max` and a `missing` fact count as not judged offline when the log does not contradict them. A state probe is not judged either, because it needs the game.
- Diagnostic checks are left out.
- It prints the fixture's age and warns when `fixture.json` is missing or its digest differs from the plan's. Record the fixture again after a plan or log text change.
- It tests the plan's text against the log. It does not run the addon, and it does not replace a run in the game.

## Check addon code offline

A plan may hold a top-level `offline` block. `.venv/bin/python tools/ct.py offline plans/<addon>.yaml` loads the addon's TOC files in the fake client and runs the block. It needs `luajit`. The installed skill has everything else. `--addons` defaults to the folder above the repository (above the current folder when `ct.py` runs from the installed skill). It prints JUnit and exits 1 when a step fails, and 2 when the plan has no block or the run cannot start. Compile removes the block, so the game never receives it and the plan digest ignores it.

**It runs the addon's Lua with your permissions.** The plan's `toc` is read from inside the folder you pass with `--addons` (default: the folder above this repository), and a path that leaves that folder is refused. Pass only addons you trust, and treat a plan from someone else like code.

```yaml
offline:
  toc: wow-keepthat/KeepThat/KeepThat_Vanilla.toc   # inside the folder you pass as --addons
  level: 4                                        # newest offline level; see Level below
  mocks:                                          # set before the addon loads
    GetItemInfo:
    - { args: [7], returns: [Mocked Seven] }
    - { returns: [Mocked Other] }
  steps:
  - label: Name comes from the mock
    call: { addon: KeepThat, entry: name, args: [7] }
    returns: [Mocked Seven]
  - { event: { name: MERCHANT_SHOW } }
  - { mockCalls: { api: GetItemInfo, count: 1 } }
```

- **Level.** `level: 2` and above give the newer fake-client answers. `GetBuildInfo` gives the number from the TOC's `## Interface:` line (the first number when the line lists several; the key counts at the start of a line only), so the addon sees the client its TOC names; a TOC with no such line gets 11507. `issecurevariable` is true for the names the fake client defines and false for names addon code set. A block without `level` runs at level 1, as before: interface 11507 and `issecurevariable` false for every name. `ct.py offline` then prints a warning. `level: 3` adds the game's load order (see Load order below), and `level: 4` the client's events and a clock (see Events and Clock below). New plans declare `level: 4`. A stricter check comes as a new level, so an existing plan keeps its result.
- **Load order (level 3).** The runner reads `## SavedVariables` and `## SavedVariablesPerCharacter` from the TOC. Those names are nil while the files run. After the last file it assigns what `savedVariables` holds, so a value the addon set at file scope is replaced, as in the game. The fresh load does not reset a table that existed before the run (#164); `ct.py offline` always starts a new process. A name with no saved value keeps what the file set, as on a first login. With `## LoadSavedVariablesFirst: 1` the values are assigned before the first file. Then ADDON_LOADED (the folder name, and whether it holds `Bindings.xml`), PLAYER_LOGIN and PLAYER_ENTERING_WORLD (`true, false`) fire at the frames that registered them, and `IsLoggedIn()` is false until PLAYER_LOGIN. An entry registered at PLAYER_LOGIN can then be called with no `event` step. `UnregisterEvent` works. A `savedVariables` name the TOC does not declare fails the load step. JSON keys are strings: use a `reload` to test number keys.
- **Reload (level 3).** A `{ reload: true }` step fires PLAYER_LEAVING_WORLD, PLAYER_LOGOUT and ADDONS_UNLOADING (`false`: the client is not closing). It then keeps each saved variable as the game writes it: strings, numbers, booleans and tables, without functions or metatables. Two references to one table come back as two tables, and a reference to a table it is inside is dropped. Then the addon loads fresh: its other globals, frames, entries and upvalues are gone. The saved values come back and the login events fire with PLAYER_ENTERING_WORLD `false, true`. Mocks are set again and their counts go on. The fresh load runs in the same Lua process. It puts back the global table and the `string`, `table`, `math`, `bit` and `coroutine` tables, so a change an addon makes elsewhere, such as to a metatable, can still leak.
- **Groups (level 3).** Put `groups` in place of `steps` to give each case its own load:

  ```yaml
  offline:
    toc: MyAddon/MyAddon.toc
    level: 3
    mocks: { GetMoney: { returns: [0] } }           # every group
    groups:
    - label: Rich
      mocks: { GetMoney: { returns: [100000] } }    # over the block's mocks
      savedVariables: { MyAddonDB: { warn: true } }
      steps: [ { call: { addon: MyAddon, entry: can_buy }, returns: [true] } ]
    - label: Poor
      steps: [ { call: { addon: MyAddon, entry: can_buy }, returns: [false] } ]
  ```

  Each group starts from a fresh load, with its own `savedVariables` or else the block's, never the previous group's. Mock counts start at zero in each group. JUnit names a group's steps `offline.G.N` and labels them `group label: step label`. A block without groups keeps `offline.N`.
- **Events (level 4).** `RegisterEvent` and `RegisterUnitEvent` raise `Frame:RegisterEvent(): Attempt to register unknown event "NAME"` for an event the client does not have, as the game does. `RegisterUnitEvent(event, "player")` gets the event only when its first value is `"player"`. An `event` step whose event the client lacks, or that gives more values than the event carries or fewer than it always carries, fails the load step before any file runs: `{ event: { name: BAG_UPDATE, args: [0] } }`, not `{ event: { name: BAG_UPDATE } }`. The lists are `tools/events/era.json` (TOC interface below 16000) and `tools/events/forever.json` (16000 and up), made from Blizzard's published UI source with `luajit tools/events_manifest.lua <wow-ui-source checkout> <client> <interface>`. An event that only Blizzard's code registers is listed with `documented: false`, and its values are not checked.
- **Clock (level 4).** `GetTime()` starts at 1 and `time()` at 1764028800, and both follow a virtual clock. A `{ wait: 2 }` step moves the clock on 2 seconds and runs each `C_Timer.After`, `NewTimer` and `NewTicker` callback that comes due, by due time and then in the order they were made. A timer made during the wait runs in it when it comes due. `NewTimer` and `NewTicker` return a handle with `Cancel` and `IsCancelled`. A callback that throws fails the wait step, and so do more than 100,000 callbacks in one wait. `time{year = ...}` converts a date. The clock goes on across a `reload`, but pending timers are lost, as in the game. Each group starts again at 1. `OnUpdate` scripts do not run.
- **Lua 5.1 check.** The game runs Lua 5.1 and the tests run LuaJIT. Before anything loads, `tools/lua51_check.lua` scans every file the TOC loads, XML and libraries included. A finding stops the run at the load step with `file:line: message`. It finds `goto` and `::labels::` (Lua 5.1 rejects them), the `\x`, `\z` and `\u{` escapes in a string the `LL`, `ULL` and `i` number suffixes, hex fractions and `p` exponents, `0b1010` and `1_000` (Lua 5.1 rejects or reads them differently) and a `[[` inside a `[[ ]]` string or comment (Lua 5.1 rejects it; `[=[ ]=]` is fine). `goto` as a name, as in `local goto = 1`, passes. Run it alone with `luajit tools/lua51_check.lua <files or TOC>`.
- **Hidden globals.** While the addon's code runs, `io`, `os`, `jit`, `ffi`, `require`, `package`, `loadfile` and `dofile` are nil, as in the game. A guard such as `if io then` sees nil and a call fails with Lua's own file and line. They come back when the run ends, nil ones too (an addon that assigns `ffi` does not leak it), also when a step fails in an unexpected way: the run then fails with a step of kind `error`.
- **Nil-read report.** The runner records each global that the addon's own files (not a `Libs/` or `Libraries/` folder, any letter case) read as nil, and `ct.py offline` prints them after the summary and in the JUnit `<system-out>`, with the interface and build in `<properties>`. The fake client lacks many names the game has, so this list shows where the run may have taken a branch the game does not take. With a census manifest for the interface (`tests/manifests/*.json`) it splits the names into present in that build's census, set by addon code in that census session, and absent from it. When several builds share the interface, it says so and lists the names unclassified: pick one with `--build <build>`. The report is advisory: counts and exit codes do not change. It does not prove that a present name behaves as in the game, and it sees only reads of nil, not a name the fake defines wrongly.
- **TOC.** The runner loads each `.lua` line of the TOC and follows each `.xml` line, such as `embeds.xml`: every `Script` and `Include` file it names loads in order, relative to that XML file, as in the game. XML comments are skipped. A path with `..`, a leading `/` or `\` or a drive letter, in the TOC or in an XML file, stops the run before any file loads. XML frame templates and inline `<Script>` code are not run.
- **Covers.** A plan with `covers:` is checked against the addon's specs, as with `validate`: `--specs <folder>`, or the nearest `openspec/specs` above the plan file.
- A `call` runs only an entry the addon registered with `CheckThat.Entry`. In the fake client `CheckThat.Entry` is a stub that applies the same name rules as the game. A name that is not registered fails the step. An addon should register at `PLAYER_LOGIN`, not at file scope, because the addons CheckThat lists as optional load first and `CheckThat.Entry` does not exist yet (see [Entry points](features.md#entry-points)).
- Add `returns` (a list) or `throws` (text the error contains) to a call.
- Only APIs on the runner's list can be mocked (`Runner.MOCKABLE` in `tools/entry_runner.lua`). A plan cannot add to it.
- Set `mockAfterLoad: true` to mock after the addon loads. A file-scope `local f = f` then keeps the real function.
- An offline pass does not prove the game agrees. Whether a replaced global taints a protected action is not measured (#98).

## Call an entry from a step

An auto step can call a function the addon registered with `CheckThat.Entry` (see [Entry points](features.md#entry-points)). The outcome is a fact line, so assert on it:

```yaml
- id: kt.add
  title: Add two numbers
  auto: true
  action: { kind: manual, text: CheckThat calls the entry. }
  expect: The entry returns 5.
  verify: [assertions]
  call: { addon: KeepThat, entry: add, args: [2, 3] }
  assertions:
  - { kind: log, source: facts, equals: '[KeepThat] entry.add=5' }
```

The step needs the `facts` log source. `call` works only on an auto step. The same entry can be called offline with the [offline block](#check-addon-code-offline).

## Check what the plans cover

```
.venv/bin/python tools/ct.py coverage plans/<addon>.yaml [more plans of the same addon] --addon-src <addon folder> [--specs <folder>] [--evidence [--dest evidence]] [--format md|json]
```

The report lists each slash subcommand, setting key and spec requirement of the addon as covered (with the ids of the steps that cover it) or unused. It reads the addon's Lua source, so a refactor can change what it finds. An extractor that finds no subcommand is an error.

- **Subcommands** come from `cmd == "name"` in the addon's `Slash*.lua` files and in every Lua file its TOC lists (a `.xml` entry or `embeds.xml` is followed; `Libs` is skipped). A step covers one when its action text, `commands`, macro, setup or cleanup holds `/alias name`. An addon that registers through `SlashCmdList` another way needs its own extractor.
- **Settings** come from AceConfig widgets (`key = { type = "toggle" ...` or `add(group, "key", { type = "toggle" ...`) and from the dotted keys of a `Settings*.lua` table. A step covers one when a slash command in its text names the key, or when a fact check uses it as its key (or its last dotted parts), or a state probe as its name or path.
- **Requirements** come from the `### Requirement:` headings of `openspec/specs/*/spec.md` next to the addon folder (or `--specs`). A step or section names what it covers with `covers`:

```yaml
sections:
  - id: tally
    covers: [The tally window lists every item]
    steps:
      - id: tally.open
        covers: [The tally is saved with the character]
```

`covers` is for the tools. `validate` fails for a name that matches no heading, or when no specs folder is found (use `--specs`). Compile drops the field, so the compiled string and the plan digest do not change. The schema rejects every other unknown field. The game ignores unknown fields, so a field for the tools never stops an import.

- **Evidence.** `--evidence` joins the newest finished run of each plan (same addon and plan title) from the collected runs. Each covered item reads `passed` (a covering step passed), `failed` (a covering step failed or is unverified) or `never-run` (the run skipped or lacks it, or the plan has no finished run).

## Good logs make good plans

A step can only be checked from a log if the addon writes the line. See [Debug logging](debug-logging.md).

## Categories

```yaml
categories:
- id: bank
  title: Bank
- id: mail
  title: Mail
sections:
- id: s1
  title: Bank steps
  category: bank        # the default for every step in the section
  steps:
  - id: bank.open
    category: mail      # a step can name its own
```

Without `categories`, each section is a category. With them, every step must resolve to one. A category id is lower case letters, digits, `.`, `_` or `-`. Do not give a category the id of a step: `/ct run` refuses a name that matches both. The id `failed` is reserved for `/ct rerun failed`; validation rejects it (also as a section id when the plan declares no categories).

## Unit-test checks

Write them in a step's `assertions`. See [Feature reference](features.md#unit-test-checks) for how each is judged.

```yaml
logs:
  facts: { global: CheckThatDB, path: global.facts, format: strings, cap: 300 }
  errors: { global: CheckThatDB, path: global.errors, format: strings, quiet: true, cap: 100 }
# in a step:
    assertions:
    - kind: fact            # a value in a range
      source: facts
      addon: KeepThat
      key: freeSlots
      op: between
      value: [1, 5]
    - kind: fact            # a number within a tolerance
      source: facts
      addon: KeepThat
      key: ratio
      op: approx
      value: 0.5
      tolerance: 0.01
    - kind: fact            # reported at least twice
      source: facts
      addon: KeepThat
      key: sold
      op: exists
      count: { min: 2 }
    - kind: log             # no Lua error since the step opened
      source: errors
      pattern: .
      absent: true
```

Each line of the error list carries the addon its file path names: `<time>.<n> [KeepThat] <message>`. To show that your addon raised no error and ignore the rest, use `pattern: "%[KeepThat%]"` with `absent: true` (a Lua pattern: escape the brackets). A line with no path reads `[?]`. Code a library loads for you carries the library's own path, so a library that ships as its own addon shows its own name.

A step can expand into many with `cases`. `{{name}}` in the step's text is replaced for each case, and the ids become `id.case`:

```yaml
- id: bind
  title: Bind a {{slot}} item
  expect: Chat says the {{slot}} item is bound.
  cases:
  - { id: cloth, vars: { slot: cloth } }
  - { id: mail, vars: { slot: mail } }
```

A unit test in an addon is its own command (for example `/kt selftest`) that calls the code and reports facts. The step runs that command with Run, and an `auto` step passes when the facts arrive.

## Facts from the addon under test

An addon that has no debug log line for a result can publish a fact instead. It calls `CheckThat.Report("KeepThat", "bagFull", true)` (see [Feature reference](features.md#facts-from-other-addons)). Add the facts list as a log source, then assert on the line like any other:

```yaml
logs:
  facts:
    global: CheckThatDB
    path: global.facts
    format: strings
# in a step:
    assertions:
    - kind: log
      source: facts
      equals: '[KeepThat] bagFull=true'
```

The plan format does not change. With `auto: true` the step passes when the addon reports the fact. A fact reported before the step opened does not count.
