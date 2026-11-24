# Design

## Context

Plans already read any saved-variable log through a `logs:` source (`global`, `path`, `format`). `Evidence.NewLines` handles positions and ring rollover for any such log. Auto steps re-read evidence twice a second. See proposal.md - Why.

## Goals / Non-Goals

**Goals:**
- Data-only facts from sibling addons, readable by plans with no plan-format change.
- A safe public function: no errors reach the caller, no cost when no run is open.
- A stable surface that only grows.

**Non-Goals:**
- Callbacks, executed code, or state snapshots from another addon (imported data is never executed).
- Facts outside a run. Nothing is recorded when no run is open.
- Reading other addons' facts back through the API.
- Wowless-style event triggers (#24 closed as covered by auto-step polling).

## Decisions

- **Facts are log lines in a CheckThat-owned list.** `CheckThatDB.global.facts` is an array of strings `[addon] key=value`. The existing log reader, positions and absence rules apply unchanged. Alternative, a typed key-value table: rejected, because plans would need a new assertion kind and a schema change.
- **Logic in `Model/Facts.lua`, plain Lua.** It validates, formats, rate-limits and appends. It takes the saved table, a clock and an "is a run open" function, so it needs no game.
- **The global is set through `Adapter`.** `Core/Adapter.lua` is the only file that writes game globals, so it exports `CheckThat`. The `Report` function wraps `Facts.Report` in `pcall`.
- **Limits.** Addon name 1 to 32 characters of letters, digits, `_` and `-`. Key 1 to 48 characters of the same set plus `.`. String value up to 120 characters with no control characters. 300 lines kept. 30 facts per addon per second, by whole-second windows from `Adapter.Now`.
- **Values.** Booleans print `true` or `false`. Numbers print with `%.14g`, and NaN and infinity are rejected. Strings print as given.
- **Run gate.** `Report` records only while `App.Current()` is a run with no `endedAt`. The gate is passed in, so `Facts` does not import `App`.
- **Compatibility.** `API_VERSION = 1`. Later releases add arguments or functions at the end, keep the line format and raise the version only for additions.
- **Debug.** One log line per accepted fact (area `facts`) and per dropped fact with the reason, once a second per addon for floods. The report adds "Facts: N, last: ...".
- **Skill, not compiler.** The skill and `docs/debug-logging.md` teach the facts source. `LOGS` in `tools/ct.py` stays as it is: it feeds only the legacy markdown converter, and YAML plans declare their own `logs`. Adding `facts` there would be dead code. A test checks the guide and skill text and validates a plan with the source.
- **Version.** New capability: 0.8.3 to 0.9.0 in both TOC files at archive.

## Risks / Trade-offs

- A public API is a promise. The version constant and the additive rule limit the cost.
- A hostile or buggy addon could crowd out another addon's facts in the shared 300 lines. The per-addon rate limit bounds this, and the list is cleared of nothing, so positions stay valid.
- An addon could reuse another addon's name. Facts are evidence for testing, not security, and the docs say so.
