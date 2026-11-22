## 1. Specs and review

- [x] 1.1 Review the four delta specs with the user and revise
- [x] 1.2 Codex review of specs and step schema against KeepThat; fold findings in
- [x] 1.3 Write the JSON Schema (`schema/test-plan.schema.json`)
- [x] 1.4 Validate samples against the schema (`make test`)

## 2. Build

- [x] 2.1 Compiler, validator, decoder, markdown converter, collector and report (`tools/wtt.py`, `tools/sv2json.lua`)
- [x] 2.2 Addon codec, plan validation, evidence, run state machine, app logic with luajit tests
- [x] 2.3 Addon UI, slash commands, macro helper, TOCs for Classic Era and Forever/Camelot
- [x] 2.4 Convert KeepThat, DontDoThat and ClosestVendor plans (31, 4 and 466 steps) and check they decode and validate in the addon
- [x] 2.5 Confirm log paths against the real saved variables of all three addons
