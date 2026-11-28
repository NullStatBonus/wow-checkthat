# Proposal

## Why

An addon developer can reach the fake client only through a plan's offline block. They have no supported way to write unit tests for their own addon against it (#273). The first slice (Lua hook steps, `ctx`) gave the fake client a public API, but only from inside a plan.

## What Changes

- **`ct test [folder]`**, a new stable command. It runs every `<folder>/tests/test_*.lua` of the developer's addon against each client the addon has a TOC for (Era below interface 16000, Forever from 16000), at the newest offline level. `--client era|forever|both`, `--name TEXT` and `--recordings DIR` narrow or extend a run. It prints one line for each test and client, the nil-read report for each client, and a summary, and exits 1 when a test fails.
- **A test file** gets `ct` as its `...`: `ct.test(name, [options,] fn)` registers a test, and `ct.API` is 1. Each test gets a fresh load of the addon and calls `fn(ctx)` with the same `ctx` as a hook step. `options` takes `mocks` and `savedVariables` in the offline block's shapes.
- **`ctx` gains fields** (additive): `ctx.reload()` (the game's reload: logout events, saved variables kept, a fresh load; `ctx.ns` follows), `ctx.ok(value, what)` and `ctx.raises(fn, text, what)`. Hook steps get them too.
- `tools/addon_test.lua` (the Lua side) joins the bundle. Docs: a new `docs/addon-tests.md`, the stable list in `docs/tools-guide.md`, `docs/skills.md`, the `ctx` table in `docs/authoring-plans.md`.

## Capabilities

### New Capabilities

### Modified Capabilities
- `offline-entry-runner`: the developer's own tests run through `ct test`, and the hook context gains `reload`, `ok` and `raises`.

## Impact

Tools, tests, docs and the bundle only. No file under `CheckThat/` changes, so no version bump. Plans and offline blocks keep their results: hook steps gain fields, nothing changes meaning. Closes #273.
