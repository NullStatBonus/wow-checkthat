# Tasks

## A. Client census (#146)

- [x] 1. Add `Model/Census.lua` (pure walk, time budget, combat pause and resume, store on completion) to both TOC files
- [x] 2. Add the census reads to `Core/Adapter.lua` and expose them through `Adapter.Env()`
- [x] 3. Add `/ct census` to `Core/Slash.lua`, the diagnostics help line and the resume on PLAYER_REGEN_ENABLED in `Core/Addon.lua`
- [x] 4. Add `ct.py census` (export per build, `-o`, `--diff`)
- [x] 5. Test the walk in `tests/test_census.lua`, the adapter reads, the slash path, and the tool in `tools/test_ct.py`
- [x] 6. Update README, `docs/features.md`, `docs/harvesting.md`, `docs/listing.md` and `docs/test-plan.md`
- [x] 7. Run `make test` and `make check`

## B. Offline runner fidelity (#145 interface, #147, #148)

- [x] tools/lua51_check.lua: lexer, module and command line, `--globals` check from the bytecode listing
- [x] tests/test_lua51.lua: each finding kind, comments, long strings, `local goto = 1`
- [x] tests/harness.lua: `H.recordNilReads(prefixes, excludes)`
- [x] tools/entry_runner.lua: interface from the TOC, Lua 5.1 scan before load, hidden globals, nilReads and interface in the result
- [x] tests/test_entries.lua and the MockAddon fixtures: interface, goto load failure, hidden io, nilReads, Libs excluded
- [x] tests/test_divergence.lua and tests/fixtures/nil-reads.txt baseline with a reason for each name
- [x] tools/ct.py offline: report to stderr and JUnit system-out, interface and build properties, manifests, `--build`
- [x] tools/test_ct.py: no manifest, one manifest, ambiguous interface, `--build`
- [x] Makefile: `make check` runs the scanner over both TOC files; bundle includes tools/lua51_check.lua
- [x] docs/authoring-plans.md and docs/contracts.md

## C. Review and archive

- [x] C.1 Opus review of the branch and a second Opus pass on the fixes; every finding fixed. (Codex was at its usage limit; its review runs after the commit.)
- [x] C.2 Sync specs, bump to 0.21.0 in both TOCs, CHANGELOG section, archive.
