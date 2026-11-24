# Write a plan

A plan is a YAML file in `plans/` that follows `schema/test-plan.schema.json`. CheckThat imports it as a `!CT1!` string.

## Steps

1. **Write or convert.** Draft a plan from an existing manual test document:

   ```
   .venv/bin/python tools/ct.py from-md ../wow-keepthat/docs/test-plan.md --addon KeepThat -o plans/keepthat.yaml
   ```

   Or ask the [plan skill](skills.md) to interview you and draft it.
2. **Validate.** `.venv/bin/python tools/ct.py validate plans/<addon>.yaml`.
3. **Compile.** `make build` writes `build/*.ct`. Compile one plan with `.venv/bin/python tools/ct.py compile plans/<name>.yaml -o build/<name>.ct`.
4. **Import and run.** In game, `/ct import`, paste, then `/ct start <addon>`.

The plan format is specified in `openspec/specs/test-plan-format/`. Rules for automatic steps are in the [feature reference](features.md#automatic-steps). Screenshots are in [Collect evidence](harvesting.md#screenshots).

## Plans in this repository

- `plans/<addon>.yaml` are short samples (4 to 7 steps each) that `make build` compiles. `plans/selftest.yaml` is the runner's own plan, not a sample. It has 14 steps (15 after `cases` expand) and uses every kind of check: log lines, fact operators, counts, state probes, the quiet error source and `cases`.
- `plans/full/` holds the full conversions of the sibling test plans. The tests validate them and `make build` does not compile them. Compile one with `tools/ct.py compile plans/full/<name>.yaml -o build/<name>-full.ct`.
- `plans/checkthat-openrun.owner.yaml` and `plans/checkthat-openrun.viewer.yaml` are a plan set for two characters on one account. The owner leaves a run open. The viewer checks that Open run is unavailable for it and that Export run and Delete run work. Run the owner plan first. Read both runs back with the verify skill.

## First live run

Run `build/selftest.ct` first. It exercises the card, copy boxes, the Run button, log evidence, reload resume, every fact and state operator, counts and Lua error capture with no sibling addon.

1. `make build`, then copy `CheckThat/` to `Interface/AddOns/`.
2. In game, `/ct import` with the contents of `build/selftest.ct`, then `/ct start CheckThat`.
3. Do the steps, then `/ct export` and `/reload`.
4. [Collect the evidence](harvesting.md).

Next, try `build/dontdothat.ct`.

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

Without `categories`, each section is a category. With them, every step must resolve to one. A category id is lower case letters, digits, `.`, `_` or `-`. Do not give a category the id of a step: `/ct run` refuses a name that matches both.

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
