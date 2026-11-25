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

- `plans/<addon>.yaml` are short samples (4 to 7 steps each) that `make build` compiles. `plans/selftest.yaml` is the runner's own plan, not a sample. It has 15 steps (16 after `cases` expand) and uses every kind of check: log lines, fact operators, counts, state probes, the quiet error source and `cases`.
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

For a plan about another addon, the replay writes the lines the checks look for into the plan's own log source (a literal line, a pattern's shortest match, each item of a sequence), marks an automatic step's `/reload` as done and prints `evidence assumed`, so most plans need no hooks file. It warns `evidence not derived` for a check it cannot write (a back-reference in a pattern); give that step a hooks `action`. Because the replay writes those lines itself, a pass says nothing about whether the addon logs them. `ct.py lines plans/<addon>.yaml --addon-src <addon folder>` checks that each asserted line and fact key appears in the addon's Lua source (a line built at run time matches on its longest plain part; `--strict` exits 1 on a miss). The offline block and `replay --sv` are the checks that prove it without the game.

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

- **Subcommands** come from `cmd == "name"` in the addon's `Slash*.lua` files. A step covers one when its action text, `commands`, macro, setup or cleanup holds `/alias name`. An addon that registers through `SlashCmdList` another way needs its own extractor.
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
