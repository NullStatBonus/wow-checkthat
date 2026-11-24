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

- `plans/<addon>.yaml` are short samples (4 to 7 steps each) that `make build` compiles.
- `plans/full/` holds the full conversions of the sibling test plans. The tests validate them and `make build` does not compile them. Compile one with `tools/ct.py compile plans/full/<name>.yaml -o build/<name>-full.ct`.
- `plans/checkthat-openrun.owner.yaml` and `plans/checkthat-openrun.viewer.yaml` are a plan set for two characters on one account. The owner leaves a run open. The viewer checks that Open run is unavailable for it and that Export run and Delete run work. Run the owner plan first. Read both runs back with the verify skill.

## First live run

Run `build/selftest.ct` first. It exercises the card, copy boxes, the Run button, log evidence and reload resume with no sibling addon.

1. `make build`, then copy `CheckThat/` to `Interface/AddOns/`.
2. In game, `/ct import` with the contents of `build/selftest.ct`, then `/ct start CheckThat`.
3. Do the steps, then `/ct export` and `/reload`.
4. [Collect the evidence](harvesting.md).

Next, try `build/dontdothat.ct`.

## Good logs make good plans

A step can only be checked from a log if the addon writes the line. See [Debug logging](debug-logging.md).

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
