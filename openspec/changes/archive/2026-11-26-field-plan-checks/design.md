## Context

Three findings from a ClosestVendor 1.13.1 run (#221, #222, #224). All three are checks in `tools/ct.py` that a plan author runs before a tester does.

## Goals / Non-Goals

**Goals:**
- Catch a version step that lets an old build pass.
- Catch player text that points at a step number.
- Stop false "not found" lines for format strings.

**Non-Goals:**
- `ct report --expect-version` defaulting to the TOC version (#221, optional part). `report` reads collected runs and has no addon folder; the skill already passes `--expect-version`. Tracked in #226.
- Showing the step number on the card (#222 alternative). That is addon UI; #218 discusses card layout.

## Decisions

- **Version: compare numbers, warn only.** The repository's version facts use `major*10000 + minor*100 + patch` (reference.md, "Version check"). The TOC's `## Version:` is parsed as `major.minor.patch` and converted the same way. For `ge` or `gt` the warning fires when the value is lower than the TOC's; for `eq` when it differs. A string value or a TOC version that does not parse gives no warning. Only the first step is read, because that is where the skill puts the version check.
- **Where the TOC comes from.** `--addon-src` picks the folder's `*_Vanilla.toc` first, as `coverage --harness` does, else the first `*.toc`. Without it, `offline.toc` is tried under `default_addons()`, the same folder `ct offline` reads, so a plan with an offline block gets the check with no flag. A missing file is silent.
- **Step references apply to every plan.** A step number in player text never helps a player, and the warning never fails validation, like the size warning from #162. The pattern is `check` or `step` followed by a dotted number, or one of the plan's own step ids as a whole word. Repository plans are checked; any that warn are fixed or listed.
- **Format strings: exact substring test.** Each quoted Lua string with a `%` conversion becomes a token list (characters and wildcards). A small automaton tests whether the asserted line is a substring of some expansion: start at any token, a wildcard consumes any characters, accept at any token. It counts the literal characters matched on each path and needs at least 8 (the floor of the word-run rule) and at least half of the asserted line, so one trailing placeholder cannot take the rest of the line. This replaces no existing rule; it is tried after them.

## Risks / Trade-offs

- An addon that encodes its version fact differently gets a wrong warning. → It is a warning, and the message shows both versions so the author can see the mismatch.
- A step id that is also a plain word could false-match. → Ids are matched only when they contain a dot, as every repository and skill id does.
