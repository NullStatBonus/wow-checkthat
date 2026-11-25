## Context

The issue asks for three layers: commands and settings, requirements, and run evidence. `ct.py` already has `expand_cases`, `merge_sections`, `latest_runs` and `run_model`.

## Goals / Non-Goals

**Goals:**
- A report of used and unused commands, settings and requirements, with step ids.
- `covers` as a tool-only field.
- The run evidence of each covered item.

**Non-Goals:**
- Line coverage. Making `covers` required.
- Dumping the real options table and slash handlers under the addon's harness, and other addons' `SlashCmdList` registration: deferred to #112. The extractors here read source text; see Decisions.

## Decisions

1. **Extractors read source text.** Commands: `cmd == "name"` in the addon's `Slash*.lua` files. Settings: AceConfig widgets (`key = { type = "toggle" ...` or `add(group, "key", { type = "toggle" ...`) and dotted keys in a `Settings` table (`["card.scale"] = {`). An extractor that finds nothing is an error, so a refactor cannot silently report everything as covered.
2. **What covers an item.** A command is covered when a step's action text, commands, macro, setup or cleanup holds `/alias name`. A setting is covered when a step names the key in that text, in a fact key (the whole key or its last dotted parts) or in a state probe name or path.
3. **`covers` is validated against the specs.** `validate` and `compile` read `openspec/specs/*/spec.md` found by walking up from the plan file, or `--specs`. A plan with `covers` and no specs folder is an error.
4. **`covers` is stripped in `merge_sections`**, as `offline` is, so the compiled string is byte-identical.
5. **Unknown fields.** The schema keeps `additionalProperties: false`, so tools reject them. `Plan.Validate` does not check fields, so the game ignores them. The spec now says so, and `tests/test_plan.lua` pins it.
6. **Evidence.** For each plan: the newest finished run with the same addon and plan title. An item is passed when any covering step passed or partial passed, else failed or unverified when a covering step did not, else never run.
