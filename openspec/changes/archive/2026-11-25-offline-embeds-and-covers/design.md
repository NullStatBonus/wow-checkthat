# Design

## Context

Two TOC loaders exist. `tests/harness.lua` `H.loadToc` follows `Script` and `Include` entries in XML files, but passes `"CheckThat"` as every file's addon name, stops on the first error with `assert`, and checks no path. `tools/entry_runner.lua` `loadToc` passes the addon's own name, returns `false, err`, and refuses TOC lines that leave the folder, but skips every line that is not `.lua`. `test_smoke` uses the first on CheckThat's real Ace3 libraries, so the fake client can already run them.

`ct.py` `validate` and `compile` pass `plan_requirements(plan, a.plan, a.specs)` to `validate`; `offline_plan` calls `validate(plan)` alone, so `check_covers` refuses any `covers:`.

## Goals / Non-Goals

**Goals:**
- One place that turns a TOC into the ordered list of Lua files, used by both loaders.
- The same path checks for XML `file=` values as for TOC lines.

**Non-Goals:**
- XML frame templates (`<Frame>`, `<Button>`, virtual templates) and inline `<Script>` bodies. The fake client cannot build XML frames, and none of the Ace3 modules the sibling addons ship need one. They are ignored, and the docs say so.
- Symlink checks. Lua has no `realpath`; the string checks match what the TOC loader does now.
- `##`-tag handling, client-specific TOC lines and `[Family]` variables.

## Decisions

- **D1. A shared file list, two runners.** Add `H.tocFiles(toc)` to the harness: it returns the TOC's Lua files in load order (following XML recursively) or `nil, err` for a path that leaves the addon folder or an XML file that cannot be read. `H.loadToc` keeps its signature and `assert` behavior and runs the list with `"CheckThat"`. The runner's `loadToc` runs the list with the addon's name and namespace under `pcall`. Alternative: give `H.loadToc` options for name and error mode. Rejected: one function with two error styles is harder to read than a list and two short loops.
- **D2. The check runs on every path, before loading.** `H.tocFiles` builds the whole list first, so a bad path in a late XML file stops the run before any addon file runs. It applies to CheckThat's own TOC too, which has no such path.
- **D3. The addon folder is the TOC's folder.** A path is refused when it holds `..`, starts with `/` or `\\`, or has a drive letter, the same rule as for TOC lines. XML paths are joined to the XML file's folder, which is inside the addon folder, so the rule holds for nested includes.
- **D4. `offline` gets `--specs`.** `offline_plan(plan, addons, requirements=None)`; the command passes `plan_requirements(plan, a.plan, a.specs)`. Default discovery already walks up from the plan file to `openspec/specs`, so a plan in an addon checkout finds that addon's specs.

## Risks / Trade-offs

- [An Ace3 module needs something the fake client lacks] → `test_smoke` already loads the same modules; KeepThat's workaround ran its whole `embeds.xml` list.
- [A library file now gets the addon's name instead of `"CheckThat"` in the harness path] → The harness path keeps `"CheckThat"`; only the runner passes the plan's addon name, as the game does.
- [A file named with `..` inside its name, such as `a..b.lua`, is refused] → Same as today for TOC lines; no sibling addon has one.
