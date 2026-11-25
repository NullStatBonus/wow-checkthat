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

- `plans/<addon>.yaml` are short samples (4 to 7 steps each) that `make build` compiles. `plans/selftest.yaml` is the runner's own plan, not a sample. It has 14 steps (15 after `cases` expand) and uses every kind of check: log lines, fact operators, counts, state probes, the quiet error source and `cases`.
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

Before a tester runs a CheckThat plan, play it in the fake client: `make build`, then `luajit tests/replay_plan.lua build/<plan>.ct [hooks.lua]`. It starts a run and does what a tester does at each step: it writes the debug lines and facts the step's checks need, lets an automatic step settle, and presses Pass. It prints each step's result and exits 1 on a problem:

- a step asserts the line its own result writes (`[ct] step <its id> ...`). CheckThat judges the result first, so the result stays unverified and the card does not advance;
- an automatic step never settles, or a step has no result after its action;
- a step never gets reached.

It warns when the card shows a step a second time, because the step's text must cover both visits. A hooks file (`tests/replay/checkthat-0.17.lua` is an example) says which result to press (`verdict`), which steps the card shows again on purpose (`revisits`), and what to do for a step that moves the card, such as Undo, a click on a step row or Remove from run (`action`). `tests/test_replay.lua` replays the 0.17 plan on every `make test`. It checks the plan's flow only. What the addon does is for the game.

## Check a plan against saved variables

`.venv/bin/python tools/ct.py replay plans/<addon>.yaml --sv <fixture dir>` judges the plan's log and fact checks against saved variables, with no game. It needs `luajit`. The fixture dir holds the SavedVariables `*.lua` files from a real run, with personal names removed, and may hold `fixture.json`: `{"recorded": "YYYY-MM-DD", "digest": "<plan digest>"}`. The command prints JUnit and exits 1 when a required check fails.

- The whole log is the window, as with `scope: session`. A typo in `contains` or `pattern`, a line that is not in the log, and a forbidden line that is in the log all fail.
- A check that needs the step's own window cannot pass here. `absent`, `exactly`, `max` and a `missing` fact count as not judged offline when the log does not contradict them. A state probe is not judged either, because it needs the game.
- Diagnostic checks are left out.
- It prints the fixture's age and warns when `fixture.json` is missing or its digest differs from the plan's. Record the fixture again after a plan or log text change.
- It tests the plan's text against the log. It does not run the addon, and it does not replace a run in the game.

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
