# Tasks

## 1. Facts model

- [x] 1.1 Add `CheckThat/Model/Facts.lua` (validate, format, per-addon rate limit, bounded list, run gate) and list it in both TOC files after `Model\Evidence.lua`.
- [x] 1.2 Add `tests/test_facts.lua`: recorded line, every rejected input, limits, rollover, no run open. Break each guard in turn and confirm the test fails, then restore it.

## 2. Public function

- [x] 2.1 Add an export to `Core/Adapter.lua` that sets the `CheckThat` global, guarded and in `pcall`.
- [x] 2.2 In `Core/Addon.lua`, bind `Facts` to `db.global.facts` and export `Report` and `API_VERSION` wrapped in `pcall`. Keep `tests/test_layers.lua` passing.
- [x] 2.3 Add tests: the global exists, `Report` never raises, an auto step passes from a reported fact, a fact from before the step does not count, saves from 0.8.3 load.

## 3. Debug output

- [x] 3.1 Log each accepted and dropped fact (area `facts`), and add the count and last fact to `Log.Report`. Test both. Check with `/ct log`.

## 4. Docs

- [x] 4.1 README: one or two lines. `docs/features.md`: behavior and log lines. `docs/authoring-plans.md`: the `logs:` source and an example plan step. `docs/contracts.md`: the API contract and limits.
- [x] 4.2 `docs/listing.md` and `docs/test-plan.md` (one short check: a sibling addon reports a fact and an auto step passes). `tests/test_readme.lua` still passes.

## 5. Skill and guide

- [x] 5.1 `ct-test-plan` offers a fact beside a log line (SKILL.md, reference.md). Add a "Publish a fact" section to `docs/debug-logging.md`.
- [x] 5.2 Add a test in `tools/test_ct.py` for the skill text, the guide section and a plan with the `facts` source. Mutation-check it.

## 6. Release

- [x] 6.1 Run `make test` and `make check`.
- [x] 6.2 Archive the change, sync the spec, bump both TOC files to 0.9.0 and add the `## 0.9.0` CHANGELOG section. Commit with the version in the message, then open the PR that closes #25.
