# Write a plan

A plan is a YAML file in `plans/` that follows `schema/test-plan.schema.json`. CheckThat imports it as a `!CT1!` string.

## Steps

1. **Write or convert.** Draft a plan from an existing manual test document:

   ```
   .venv/bin/python tools/ct.py from-md ../wow-dontdothat/docs/test-plan.md --addon DontDoThat -o plans/dontdothat.yaml
   ```

   Or ask the [plan skill](skills.md) to interview you and draft it. A conversion is a list to cut, not a plan to run: see [Keep a plan short](#keep-a-plan-short).
2. **Validate.** `.venv/bin/python tools/ct.py validate plans/<addon>.yaml`. It fails on a step that asserts its own result line. It warns when the first step does not check the version, and when the plan has more than 25 steps or a section more than 10 (each case counts as a step). It warns when player text (action text, `setup`, `expect`) cites a step by number or id, because the card shows titles: say what the player did in that step, or write "on purpose" in the step's notes when the game itself shows the id. With `--addon-src <addon folder>`, or when the plan's `offline.toc` exists, it warns when the first step's version fact accepts an older build than the TOC's `## Version:` (`compile` prints the same warning on stderr). A plan that sets `purpose` also gets the wording warnings and, for a foundation plan, a warning above 12 steps (see [Foundation and feature plans](#foundation-and-feature-plans)).
3. **Compile.** `make build` writes `build/*.ct`. Compile one plan with `.venv/bin/python tools/ct.py compile plans/<name>.yaml -o build/<name>.ct`. When the plan uses a key added to the format after revision 1 (the format of 0.21.0), compile writes `needs: <revision>`, and a CheckThat that reads an older revision refuses the plan with "This plan needs a newer CheckThat" instead of skipping a check it does not know. Leave `needs` out; `validate` fails a `needs` lower than the plan's keys require, or higher than the tools read.
4. **Import and run.** In game, `/ct import`, paste, then `/ct start <addon>`.

The plan format is specified in `openspec/specs/test-plan-format/`. Rules for automatic steps are in the [feature reference](features.md#automatic-steps). Screenshots are in [Collect evidence](harvesting.md#screenshots).

## Keep a plan short

A plan is for what a fake game cannot prove: real game data and events, end-to-end wiring, drawing, sound, other addons, and saved variables across `/reload`. Logic that a unit test proves gets no step.

- Each step covers a whole feature from start to finish, not one facet.
- A plan has at most 25 steps, and a section at most 10. Before each release a tester runs the foundation plan, not every plan.
- Measure coverage, do not guess it: map each spec requirement to the plan steps that cover it ([Check what the plans cover](#check-what-the-plans-cover)) and, by hand or with the addon's own coverage report, to unit tests. List the rest.
- A long plan also fills the addon's debug log during a run, so a late absence check or count cannot be proven, and state carried along a long chain of steps gives false results.

## Lists, async steps and steps for one character

- **Several actions.** `action.text` can be a list of two to six actions. The card shows one checkbox for each, and the player ticks them as they go. Ticks are saved on the attempt and the report names the ones left empty, but they never record a result. A `copy-slash` step's text stays one command.
- **Several results.** `expect` can be a list of two to six short results. The card shows one line for each. A plan that keeps both as strings looks as before.
- **Checked when the run starts.** `async: true` on an `auto` step makes CheckThat judge its required checks once, against the whole retained log, when the run starts or a rerun reopens it. A pass is recorded then (`at: "start"`) and the card never stops there. Otherwise the step waits for its turn as an auto step does. Use it for a check only this build can meet, such as a `version` fact with `eq` or a state probe: the whole log also holds lines from earlier sessions. Validation rejects it with `setup`, a `call`, a reload, or a check that something did not happen.
- **For some characters only.** A requirement can name `class` (tokens such as `MAGE`) or `profession` (names as the plan's locale shows them) and set `unmet: inapplicable`. A step that needs it is recorded as not applying when it opens on another character, with the requirement's text as the reason, and its timer never starts. Without `unmet`, an unmet requirement blocks as before. When the game cannot say the class or the professions, the requirement holds.

```yaml
requirements:
  caster: { text: This step needs a Mage or a Priest., class: [MAGE, PRIEST], unmet: inapplicable }
# in a step:
  requires: [caster]
  action:
    kind: manual
    text:
    - Walk into the dungeon.
    - Wait 10 seconds inside.
    - Walk out again.
  expect:
  - The question closes when you enter the dungeon.
  - The question is asked again outside.
```

`ct replay-flow` writes an async step's lines before the run starts, so it passes at start. A hooks file can set `unmet = { caster = true }` to take the inapplicable branch.

## Foundation and feature plans

Every plan says what it is for with `purpose`. The field is for the tools only; the compiler drops it.

- **`purpose: foundation`** is the release gate. It answers "do the systems that everything else depends on work in the real game?" Find the pillars first: the systems that, if they fail, make every feature fail. Name each with its real-game risk only, such as a game call missing on one client, a real event that never reaches the decision, or saved data lost on `/reload`.
  - One character runs it: any class, any level, no profession, in one stated place. One run per client. The preamble lists these assumptions.
  - A step that needs a class, a profession, a place, a fight or another addon moves to a feature plan, the offline block or a unit test. The preamble names it and where it went.
  - One section per pillar, one step per pillar (at most about two), 8 to 12 steps. At least one step crosses a real threshold end to end. No step exists only to put a setting back.
- **`purpose: feature`** goes deep on one feature: edge and negative cases, each client, one plan per character role, combat or instances when the feature touches them. It runs when the feature changes, not before every release. After the feature ships, retire it or keep it as a regression plan.

Write both in player language. Action text is one sentence about what the player does, and commands sit only in `commands`, behind Run. Expect says what is on screen, never what is logged.

When a plan sets `purpose`, `validate` warns, without failing, about:
- a slash command in action text or Expect (not in a `copy-slash` step's text, which is the command);
- "log", "logs", "logged" or "logging" in Expect ("log in", "log out" and "log on" are fine);
- a foundation plan over 12 steps, each case counted as a step.

A plan without `purpose` keeps its old warnings.

## Plan sets

Split a larger feature scope into a set of plans by area, for example `<name>.core.yaml`, `<name>.ui.yaml` and `<name>.addons.yaml`. One character runs them one after another. A set by area is not the release gate: the foundation plan is.

- Each plan has its own version step, setup step and final no-Lua-error step (the quiet errors source, see [Unit-test checks](#unit-test-checks)). Give it `scope: run`, so it sees every error since the run started and none from an earlier run or plan.
- Give each plan its own section range, so no section id or step id appears in two plans.
- Each preamble names every partner plan file.
- CheckThat keeps one plan for each addon, and a run starts from the last plan imported. Import, start and finish one plan before you import the next.

A check that needs several characters is a different set: one plan for each character role. See the [plan skill](skills.md).

## Test settings

A plan written for the default settings fails for a tester who changed them. A step command that sets a value also overwrites the tester's own setting. When a plan depends on the addon's settings, give the addon a test-settings mode:

- One command (for example `/<prefix> testsettings on`) puts the character's settings and frame positions aside and uses fresh defaults in place. `off` restores them exactly. The mode lasts across `/reload`, and a chat line at login says that it is on.
- Before the swap, the addon ends anything that still holds the old settings (open questions, previews, pending callbacks). It logs the swap as one line, not as one change for each setting.
- The plan's setup step runs, in this order: debug on, `testsettings on`, `/reload`. It asserts that the debug log is on, then the login line, then that test settings are on at login. Debug goes on first, because the addon drops lines while its log is off.
- The plan's last step runs `testsettings off` and asserts the restore line in that attempt.

A subcommand after the addon's slash prefix needs no CheckThat change: the allow list holds the prefix (see [Commands of the addon under test](#commands-of-the-addon-under-test)). A plan has no run-level setup or teardown, so a run that a tester abandons leaves the mode on until `off` (#171).

## Commands of the addon under test

A plan names any addon by its folder name (`addon: MyAddon`). Step commands, copy text and macros may use the shared commands (`/reload`, `/reloadui`, `/console scriptErrors 0|1`) and the addon's own slash commands. CheckThat knows the commands of a few addons already. For any other addon, list its command prefixes in the plan:

```yaml
addon: MyAddon
commands: [/my, /myaddon]
```

- A prefix is one word after the slash. `/my` covers `/my` and `/my debug on`. At most 8.
- `validate` and the import refuse `/run`, `/script`, `/dump`, `/console`, the game's debug tools (`/fstack`, `/etrace`, `/tinspect`, `/api`), `/macro`, `/logout`, `/quit` and `/camp`, and the commands of another addon CheckThat knows. A step command whose prefix is not listed fails `validate` with "list its prefix in commands".
- In game, CheckThat offers a listed prefix as a Run button or in the CT macro only when the addon under test registered that slash command: the game says which addon wrote the `SLASH_<NAME>1` global. A command another addon or the game registered is never offered; the tester can still type it. The start screen says which commands the plan may offer and which it does not, and the log reads `plan commands offered: /my; not offered: /x` at start.
- The addon under test can declare its commands itself, so they are offered without that check: `CheckThat.Commands("MyAddon", { "/my", "/myaddon" })` (see [Adopt CheckThat](adopting.md)). A plan should still list them in `commands`, so `validate` can check the steps.
- `commands` is plan revision 2: `compile` writes `needs: 2`, and an older CheckThat says the plan needs a newer CheckThat.

## Plans in this repository

- `plans/<addon>.yaml` are short samples (4 to 7 steps each) that `make build` compiles. KeepThat and ClosestVendor keep their plans in their own repositories, so none is kept here (`tests/fixtures/keepthat.yaml` is a short fixture for the tests, not the plan of record; the tests validate the KeepThat plan from `../wow-keepthat/plans/` when that checkout is present). `plans/selftest.yaml` is the runner's own plan, not a sample. It has 16 steps (17 after `cases` expand) and uses every kind of check: log lines, fact operators, counts, state probes, the quiet error source and `cases`. Its one section gets the size warning, because it checks the runner, not a feature.
- `plans/full/` holds the full conversions of the sibling test plans. The tests validate them and `make build` does not compile them. Compile one with `tools/ct.py compile plans/full/<name>.yaml -o build/<name>-full.ct`.
- `plans/checkthat-0.16.yaml` tests Remove from run and the result keys on its own run, in forever-camelot only.
- `plans/checkthat-0.16-picker.yaml` tests the category picker and the paged Home list. It needs `plans/checkthat-picker-fixture.yaml`, a ClosestVendor plan with 26 categories that is only for looking at the start screen (so it gets the size warning).
- `plans/checkthat-0.21.yaml` is the feature plan for the 0.21 card: the action checklist, the pause after a result, a step checked at run start, a step for a Mage and a final run-scoped error check. Run it on a character that is not a Mage, on each client.
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

For a plan about another addon, the replay writes the lines the checks look for into the plan's own log source (a literal line, a pattern's shortest match, each item of a sequence), marks an automatic step's `/reload` as done and prints `evidence assumed`, so most plans need no hooks file. It warns `evidence not derived` for a check it cannot write (a back-reference in a pattern); give that step a hooks `action`. Because the replay writes those lines itself, a pass says nothing about whether the addon logs them. `ct.py lines plans/<addon>.yaml --addon-src <addon folder>` checks that each asserted line and fact key appears in the addon's Lua source (a line built at run time matches on its tag and words, or on any run of its words of at least 8 characters, such as `test command` for `"test command: " .. kind` or `items found` for `"%d items found"`; a line built with `string.format` also matches across its placeholders, such as `trigger go sell (bags=` for `"trigger %s%s%s (bags=%s"`, when at least 8 characters and half of the line come from the format string; and the same holds for `equals`, `contains` and the plain part of a `pattern`; `--strict` exits 1 on a miss). The offline block and `replay --sv` are the checks that prove it without the game.

## Check a plan against saved variables

`.venv/bin/python tools/ct.py replay plans/<addon>.yaml --sv <fixture dir>` judges the plan's log and fact checks against saved variables, with no game. It needs `luajit`. The fixture dir holds the SavedVariables `*.lua` files from a real run, with personal names removed, and may hold `fixture.json`: `{"recorded": "YYYY-MM-DD", "digest": "<plan digest>"}`. The command prints JUnit and exits 1 when a required check fails.

`.venv/bin/python tools/ct.py replay plans/<addon>.yaml --run <run id> [--dest evidence]` does the same against a collected run, with no fixture folder to make. It uses the collected `CheckThat.lua` copy that holds the run at its newest revision, and the addon files of the same client and account from that collect: the account-wide ones and those of the run's own character, never another character's. It prints each file it used. Use it after you revise a plan, before you ask for another run in the game.

- The whole log is the window, as with `scope: session`. A typo in `contains` or `pattern`, a line that is not in the log, and a forbidden line that is in the log all fail.
- A check that needs the step's own window cannot pass here. `absent`, `exactly`, `max` and a `missing` fact count as not judged offline when the log does not contradict them. A state probe is not judged either, because it needs the game.
- Diagnostic checks are left out.
- For `--run`, a file that did not change since an earlier collect keeps its first copy, which is the right content. A file first collected after the run gets a warning, because it may hold lines written later.
- It prints the fixture's age and warns when `fixture.json` is missing or its digest differs from the plan's. Record the fixture again after a plan or log text change.
- It tests the plan's text against the log. It does not run the addon, and it does not replace a run in the game.

## Check addon code offline

A plan may hold a top-level `offline` block. `.venv/bin/python tools/ct.py offline plans/<addon>.yaml` loads the addon's TOC files in the fake client and runs the block. It needs `luajit`. The installed skill has everything else. `--addons` defaults to the folder above the repository (above the current folder when `ct.py` runs from the installed skill). It prints JUnit and exits 1 when a step fails, and 2 when the plan has no block or the run cannot start. Compile removes the block, so the game never receives it and the plan digest ignores it.

**It runs the addon's Lua with your permissions.** The plan's `toc` is read from inside the folder you pass with `--addons` (default: the folder above this repository), and a path that leaves that folder is refused. Pass only addons you trust, and treat a plan from someone else like code.

```yaml
offline:
  toc: wow-keepthat/KeepThat/KeepThat_Vanilla.toc   # inside the folder you pass as --addons
  level: 6                                        # newest offline level; see Level below
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

- **Level.** `level: 2` and above give the newer fake-client answers. `GetBuildInfo` gives the number from the TOC's `## Interface:` line (the first number when the line lists several; the key counts at the start of a line only), so the addon sees the client its TOC names; a TOC with no such line gets 11507. `issecurevariable` is true for the names the fake client defines and false for names addon code set. A block without `level` runs at level 1, as before: interface 11507 and `issecurevariable` false for every name. `ct.py offline` then prints a warning. `tocs: { era: ..., forever: ... }` (level 5 only, optional) names a TOC for each client. `ct.py offline plan.yaml --client era|forever|both` runs the block with that client's TOC (`both` runs it twice and prefixes each case with `era:` or `forever:`); without `--client` only `toc` runs, as before. `replay-flow` does not run the offline block: it plays the plan's steps on every client already, so `tocs` does not apply to it. A mock entry can be `{ recording: "GetItemInfo(6948)" }` (level 5 and up, not with `args` or `returns`): its arguments and return values come from a call recorded in game for the client the block runs on (`tools/recordings/era.json` or `forever.json`). The labels are the recorded calls, such as `GetItemInfo(6948)` on Era and `C_Item.GetItemInfo(6948)` on both. A call recorded at a second vendor or trainer starts with its scene name, such as `gear:GetMerchantItemInfo(1)` (a vendor that sells armor or weapons), `class:GetTrainerServiceInfo(4)` (a class trainer) or `gear:GetMoney()` (the balance at that vendor) ([Harvesting](harvesting.md)). A recording must be for the mocked function; a label the client has no recording for fails the load step, and the mock returns nothing when the call's arguments differ from the recorded ones. A recorded `nil` stays `nil`, so a count of the returns is right. A `tooltip` step (level 5 only) checks the lines the addon put on `GameTooltip` so far: `{ tooltip: { lines: 3 } }`, `{ tooltip: { contains: "Sell price" } }` (any line), or `{ tooltip: { line: 2, equals: "Title" } }`. A line matches by its left or right text, so a double line (`AddDoubleLine`) matches on either side. A miss lists the lines it found. The client's hook path is modelled: on Era `GameTooltip:HookScript("OnTooltipSetItem", fn)` runs when `SetHyperlink` or `SetItemByID` sets an item and `TooltipDataProcessor` does not exist; on Forever registering that script hook raises, and `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)` runs `fn(tooltip, data)` at the same moment. A tooltip set to an item this way gets no lines, so a `tooltip` step after `SetHyperlink` sees zero lines. The hook path applies at level 5 and up, where the client's surface is used; a hook that throws goes to the error handler and the tooltip call goes on. `level: 3` adds the game's load order (see Load order below), `level: 4` the client's events and a clock (see Events and Clock below), and `level: 5` the client's real functions and frame methods (see Client below), and `level: 6` the taint of the game's global names (see Taint below). New plans declare `level: 6`. A stricter check comes as a new level, so an existing plan keeps its result.
- **Load order (level 3).** The runner reads `## SavedVariables` and `## SavedVariablesPerCharacter` from the TOC. Those names are nil while the files run. After the last file it assigns what `savedVariables` holds, so a value the addon set at file scope is replaced, as in the game. The fresh load does not reset a table that existed before the run (#164); `ct.py offline` always starts a new process. A name with no saved value keeps what the file set, as on a first login. With `## LoadSavedVariablesFirst: 1` the values are assigned before the first file. Then ADDON_LOADED (the folder name, and whether it holds `Bindings.xml`), VARIABLES_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD (`true, false`) and SPELLS_CHANGED fire at the frames that registered them, and `IsLoggedIn()` is false until PLAYER_LOGIN. An entry registered at PLAYER_LOGIN can then be called with no `event` step. `UnregisterEvent` works. A `savedVariables` name the TOC does not declare fails the load step. JSON keys are strings: use a `reload` to test number keys.
- **Reload (level 3).** A `{ reload: true }` step fires PLAYER_LEAVING_WORLD, ADDONS_UNLOADING (`false`: the client is not closing) and PLAYER_LOGOUT, the order measured in game (it was LOGOUT before ADDONS_UNLOADING in the earlier runner; offline levels 3 to 5 are in 0.21.0, which has no release tag yet, so no released plan saw the old order). It then keeps each saved variable as the game writes it: strings, numbers, booleans and tables, without functions or metatables. Two references to one table come back as two tables, and a reference to a table it is inside is dropped. Then the addon loads fresh: its other globals, frames, entries and upvalues are gone. The saved values come back and the login events fire with PLAYER_ENTERING_WORLD `false, true`. Mocks are set again and their counts go on. The fresh load runs in the same Lua process. It puts back the global table and the `string`, `table`, `math`, `bit` and `coroutine` tables, so a change an addon makes elsewhere, such as to a metatable, can still leak.
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
- **Taint (level 6).** A game global that addon code replaces reads as insecure to `issecurevariable` from then on, and putting the original back does not clear it. This is measured in game on Era and Forever (`docs/contracts.md`). The runner compares each game global with its value at the start after every step and when `issecurevariable` is called, and keeps a change for good. `hooksecurefunc` runs your hook after the original and leaves the name secure. Limits: a replace and a restore inside one step, with no check between, is not seen; a member of a table still reads secure; and a protected action does not read taint, so `ADDON_ACTION_BLOCKED` is not raised (that needs an in-game probe). A mock of a game function taints it too, as it would in the game. Levels 5 and below keep their old answer.
- **Client (level 5).** The fake client takes the surface of the client the TOC names (`tools/clients/era.json` below interface 16000, `tools/clients/forever.json` from 16000), sliced from an in-game census. Only that client's game functions exist: `GetItemInfo` is nil on Forever, which has only `C_Item.GetItemInfo`. A function the client has that the fake client does not model is a stub that returns nothing. `strsub`, `tinsert`, `mod` and the other Lua aliases are the real functions, the trig functions work in degrees, and `Mixin`, `CreateFromMixins`, `CopyTable`, `tContains`, `strtrim`, `strjoin`, `tostringall`, `date` and the profiling clocks work. `dofile`, `load`, `loadfile`, `module` and `require` are nil, as in the game. `GetBuildInfo` gives the real build. A frame of one of the 16 widget types the census lists has only that type's methods, so a typo such as `SetPointt` reads nil and a call to it fails. A frame made from templates the surface lists (BackdropTemplate, UIPanelButtonTemplate, UIPanelScrollFrameTemplate, UICheckButtonTemplate, UIDropDownMenuTemplate) also has those templates' mixin methods and child keys. A frame from any other template still takes any method. Level 5 is not in a release yet, so no released plan meets the stricter frames. An event handler or timer callback that does too much work in one call fails with "script ran too long", as in the game. The game stopped nothing in a 3.5 s test, so its limit is not known (`docs/contracts.md`). The runner counts an instruction as 1 and a call as 20 and fails over 100,000,000, so only a runaway loop trips it. Entry calls, the load step and slash handlers have no limit. `GameTooltip` exists and keeps the lines an addon adds (`AddLine`, `AddDoubleLine`, `SetText`, `ClearLines`, `NumLines`; `SetOwner` clears them); a test reads them with `H.tooltipLines(tip)`. The client's tooltip hook path is not modelled (see #151). A mock of a function the client lacks fails the load step, because it would hide the gap. The block runs on one client, the one its TOC names (#170).
- **Lua 5.1 check.** The game runs Lua 5.1 and the tests run LuaJIT. Before anything loads, `tools/lua51_check.lua` scans every file the TOC loads, XML and libraries included. A finding stops the run at the load step with `file:line: message`. It finds `goto` and `::labels::` (Lua 5.1 rejects them), the `\x`, `\z` and `\u{` escapes in a string the `LL`, `ULL` and `i` number suffixes, hex fractions and `p` exponents, `0b1010` and `1_000` (Lua 5.1 rejects or reads them differently) and a `[[` inside a `[[ ]]` string or comment (Lua 5.1 rejects it; `[=[ ]=]` is fine). `goto` as a name, as in `local goto = 1`, passes. Run it alone with `luajit tools/lua51_check.lua <files or TOC>`.
- **Hidden globals.** While the addon's code runs, `io`, `os`, `jit`, `ffi`, `require`, `package`, `loadfile` and `dofile` are nil, as in the game. A guard such as `if io then` sees nil and a call fails with Lua's own file and line. They come back when the run ends, nil ones too (an addon that assigns `ffi` does not leak it), also when a step fails in an unexpected way: the run then fails with a step of kind `error`.
- **Nil-read report.** The runner records each global that the addon's own files (not a `Libs/` or `Libraries/` folder, any letter case) read as nil, and `ct.py offline` prints them after the summary and in the JUnit `<system-out>`, with the interface and build in `<properties>`. The fake client lacks many names the game has, so this list shows where the run may have taken a branch the game does not take. With a census manifest for the interface (`tests/manifests/*.json`) it splits the names into present in that build's census, set by addon code in that census session, and absent from it. When several builds share the interface, it says so and lists the names unclassified: pick one with `--build <build>`. The report is advisory: counts and exit codes do not change. It does not prove that a present name behaves as in the game, and it sees only reads of nil, not a name the fake defines wrongly.
- **TOC.** The runner loads each `.lua` line of the TOC and follows each `.xml` line, such as `embeds.xml`: every `Script` and `Include` file it names loads in order, relative to that XML file, as in the game. XML comments are skipped. A path with `..`, a leading `/` or `\` or a drive letter, in the TOC or in an XML file, stops the run before any file loads. XML frame templates and inline `<Script>` code are not run.
- **Covers.** A plan with `covers:` is checked against the addon's specs, as with `validate`: `--specs <folder>`, or the nearest `openspec/specs` above the plan file.
- A `call` runs only an entry the addon registered with `CheckThat.Entry`. In the fake client `CheckThat.Entry` is a stub that applies the same name rules as the game. A name that is not registered fails the step. An addon should register at `PLAYER_LOGIN`, not at file scope, because the addons CheckThat lists as optional load first and `CheckThat.Entry` does not exist yet (see [Entry points](features.md#entry-points)).
- Add `returns` (a list) or `throws` (text the error contains) to a call.
- Only APIs on the runner's list can be mocked (`Runner.MOCKABLE` in `tools/entry_runner.lua`). A plan cannot add to it. The list holds the read-only vendor, trainer and auction window calls (`GetMerchantItemInfo`, `GetTrainerServiceInfo`, `GetAuctionItemInfo` and the others CTProbe records), never a call that buys, learns or bids. A recording entry with `source` was not recorded in game ([Harvesting](harvesting.md)). `args` and `returns` may hold tables, written as JSON objects and lists: `{ args: [1], returns: [{ name: "Coarse Thread", price: 10 }] }` for `C_MerchantFrame.GetItemInfo`, or an itemKey object as an argument of `C_AuctionHouse.GetItemSearchResultInfo`. A table argument matches by value, and each call gets its own copy of a table return, as from the game.
- `predicts: { <plan step id>: [offline.1, offline.2.1] }` (optional) links a plan step to the offline steps whose result predicts it: a pass when all of them pass. `ct.py drift` compares that prediction with a real run (see [Drift ledger](harvesting.md#drift-ledger)). The ids are the ones `ct.py offline` prints.
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
.venv/bin/python tools/ct.py coverage plans/<addon>.yaml [more plans of the same addon] --addon-src <addon folder> [--specs <folder>] [--tests <folder>] [--harness] [--evidence [--dest evidence]] [--format md|json]
```

The report lists each slash subcommand, setting key and spec requirement of the addon as covered (with the ids of the steps that cover it) or unused. It reads the addon's Lua source, so a refactor can change what it finds. An extractor that finds no subcommand is an error.

- **Subcommands** come from `cmd == "name"` in the addon's `Slash*.lua` files and in every Lua file its TOC lists (a `.xml` entry or `embeds.xml` is followed; `Libs` is skipped). A step covers one when its action text, `commands`, macro, setup or cleanup holds `/alias name`. An addon that registers through `SlashCmdList` another way needs its own extractor.
- **Settings with `--harness`.** The tool loads the addon's TOC in the fake client (`tools/dump_options.lua`, needs luajit; it runs the addon's Lua, so use addons you trust) and reads the options tables the addon registered with AceConfigRegistry-3.0: every node that holds a value (toggle, range, select, multiselect, input, color, keybinding) is a setting, named by its key alone, so two settings with the same key in different groups count once. The source scan still runs and adds what it finds. The report says `settings read from: registry (N tables, X.toc) and the source`, or `source (reason)` when the registry is empty or the addon cannot load. It reads the `_Vanilla` TOC when there is one, else the first. The load stops after 60 seconds. Without `--harness` the output is as before.
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

- **Unit tests** count toward requirements. Put a `-- covers: <Requirement name>` comment above a test, one name per comment, in the `*.lua` files of the addon's `tests/` folder (next to the addon folder, or `--tests`; folders named `fixtures` are skipped). A trailing ` -- note` on the comment line is dropped. The report adds the file and line (relative to the tests folder) to each requirement; the `--evidence` result still describes plan steps only; the counts by tests, by plans, by both and by neither, the requirements in both (a plan step there may repeat a unit test) and any name no spec has. JSON adds `tests` to each requirement, plus `testCounts`, `testAndPlan` and `unknownTests`. Without a tests folder the output stays as before.

`covers` is for the tools. `validate` fails for a name that matches no heading, or when no specs folder is found (use `--specs`). Compile drops the field, so the compiled string and the plan digest do not change. The schema rejects every other unknown field. The game ignores unknown fields, so a field for the tools never stops an import.

- **Evidence.** `--evidence` joins the newest finished run of each plan (same addon and plan title) from the collected runs. Each covered item reads `passed` (a covering step passed), `failed` (a covering step failed or is unverified) or `never-run` (the run skipped or lacks it, or the plan has no finished run).

## Good logs make good plans

A step can only be checked from a log if the addon writes the line. See [Debug logging](debug-logging.md).

A plan may read any global, and the results string holds what a log source or a `global-value` check read. The start screen lists those variables before the tester starts. Name only the globals the plan needs.

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
  blocked: { global: CheckThatDB, path: global.blocked, format: strings, quiet: true, cap: 50 }   # "nothing was blocked": absent: true
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

A `pattern` (and the value of a `matches` check) is a Lua pattern of up to 200 characters. `validate`, `compile` and the game's import refuse one that Lua cannot read (an open `(` or `[`, a lone `%`, a back reference to a capture that is not there, a NUL byte: write `%z`): `string.find` raises on it or reads it differently. Every other pattern is accepted, as before, and a line is matched whole. A pattern with at most one `*`, `+` or `-` (not counting a leading `.*` or `.-`), at most three `?` and no back reference runs the game's own `string.find` on lines of up to 2000 characters, as long as the work stays small; anything else runs in CheckThat's own matcher (`Model/Pattern.lua`), which finds what `string.find` finds but counts its steps (budget 40000, 2 to 7 ms). A line that takes too long (a pattern with several wildcards on a long line of repeated text) is left unchecked: the check is unverified with "a log line took too long to check with this pattern", never pass and never fail on that line. A match on another line still passes. One card refresh may spend about 20 ms on lines it has not seen; the card then shows the check as unverified with "still checking the log (the card tries again)" for a refresh or two, and the answers kept so far cost nothing. A recorded result is never cut short that way. A plan that is already stored with a pattern Lua cannot read is not run: its check stays unverified and says why. Text, lists and `value` are never `null`: `validate` names the path of a `null` or empty YAML value. `compile` fails when the string is over the 120000 characters the game imports.

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
