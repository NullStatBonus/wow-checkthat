## Why

An offline step can only call a `CheckThat.Entry` entry, fire an event, count mock calls, wait, reload or read the tooltip. A developer cannot set up state, reach code that is not an entry, or check a result that is not a return value. #273 asks for a public test library on the fake client and names Lua hooks in offline steps as its first slice.

## What Changes

- An offline block may name a Lua hooks file, `hooks: MyAddon/tests/offline_hooks.lua` (level 5), a path inside the addons folder as for `toc`. The file returns a table of functions. It is local code the developer writes. A plan string never carries it: compile drops the offline block.
- A new step, `{ hook: <name>, args, returns | throws }`, calls `hooks[name](ctx, ...)` and judges it as a `call` step is judged. A hook that errors fails its step with the error text.
- `ctx` is the first public fake-client API, documented and additive only:
  - `ctx.ns`: the addon's private namespace (the second value of `...`) for the current load.
  - `ctx.client` (`era` or `forever`) and `ctx.level`.
  - `ctx.fire(event, ...)`, `ctx.combat(on)`, `ctx.advance(seconds)`, `ctx.mockCalls(api)`.
  - `ctx.eq(got, want, what)` and `ctx.same(got, want, what)`, which raise with the first difference.
- Hooks run with Lua's full library (the hidden globals come back for the hook and go away after it), as test code does.
- A step that names a hook the file lacks, a file that is missing or does not return a table, or `hooks` below level 5 fails the load step before the addon loads.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `offline-entry-runner`: hook steps and the `ctx` API.
- `test-plan-format`: the offline block takes `hooks` and `hook` steps at level 5.

## Impact

- `tools/entry_runner.lua` (hooks file, hook step, ctx), `tools/ct.py` (resolve `hooks` inside the addons folder), `schema/test-plan.schema.json`.
- `tests/test_entries.lua`, `tools/test_ct.py`, a fixture hooks file.
- Docs: `docs/authoring-plans.md` (a "Lua hooks" part with the `ctx` reference), `skills/ct-test-plan/SKILL.md`, `docs/skills.md` (the `tests/` note now names the hooks API as the public part).
- No file under `CheckThat/` changes, so no version bump.
