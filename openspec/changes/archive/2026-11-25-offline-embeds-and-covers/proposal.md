# Proposal

## Why

`ct.py offline` cannot run the offline block of an addon that loads its libraries through `embeds.xml`, or of a plan that uses `covers:`. KeepThat hit both while it took over its own plan (issue #135, NullStatBonus/wow-keepthat#33). Its seven offline steps pass only with a local copy of the TOC and of the plan.

## What Changes

- The offline runner follows XML files a TOC lists: each `<Script file=...>` and `<Include file=...>` loads in order, relative to the XML file, as the game does. A `file=` path that leaves the addon folder stops the run before the addon loads, as a TOC line does now.
- `ct.py offline` validates the plan with the addon's spec requirements, as `validate` and `compile` do. It takes the same `--specs` option, and without it finds `openspec/specs` above the plan file. A plan with `covers:` then runs.
- The spec text says `toc` resolves inside the `--addons` folder, which is what the code does. Today it says "from the plan file's folder".
- XML frame templates and inline `<Script>` code stay unsupported. The docs say so.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `offline-entry-runner`: the runner follows XML files in the TOC; the offline command accepts `--specs` and resolves `toc` inside the addons folder.

## Impact

- `tools/entry_runner.lua` (TOC loading), `tests/harness.lua` (shared TOC file list), `tools/ct.py` (`offline_plan`, the `offline` argument parser).
- Tests: `tests/test_entries.lua` and its `MockAddon` fixture, `tools/test_ct.py`.
- Docs: `docs/authoring-plans.md` ("Check addon code offline").
- Tools only. No file under `CheckThat/` changes, so no version bump, changelog entry or tag.
