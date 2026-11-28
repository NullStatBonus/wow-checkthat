## Context

`tools/entry_runner.lua` runs a block's steps in the fake client from `tests/harness.lua`. Everything in a block is data. A replay hooks file already exists for `replay-flow` (`tests/replay.lua`), but it steers the card, not addon code. #273 asks for a public, versioned fake-client API and names offline hooks as its first slice.

## Goals / Non-Goals

**Goals:**
- A developer can set up state, reach code outside `CheckThat.Entry`, and check any result, in Lua, inside an offline block.
- `ctx` is small, documented and additive only, so it can grow into the #273 module.

**Non-Goals:**
- A standalone `ct test` runner for `tests/test_*.lua` and the full `H` API (#273).
- Hooks before the addon loads. Saved variables and mocks already cover setup before load.
- Sharing hooks inside a plan string. A plan stays data.

## Decisions

- **The file lives in the addon's repository, named by the block.** `hooks` resolves inside the addons folder, as `toc` and `recordings` do, so `ct offline`, `predict` and `drift` all find it without a flag. It is code of the same trust as the addon the block already runs. Alternative: a `--hooks` flag as for `replay-flow`. Rejected: every command that runs the block would need it, and a block would not run the same everywhere.
- **Level 5.** Hooks run against the client's real surface, so the API is documented against one fake client. No new level: the key is new, and a block without it runs as before.
- **A hook step is judged like a call step.** Same `args`, `returns` and `throws`, so an author learns one shape. A raise without `throws` fails with the text, so `ctx.eq` and `error()` both work as asserts.
- **Hooks run with the hidden globals back**, as `opts.loaded` test code does today: a hook is test code, and may need `io` or `os`.
- **`ctx` is built per step** from the current load, so `ctx.ns` follows a reload and a group's fresh load.
- **Names are checked before load.** A typo fails the load step with the file path, not in the middle of a run.

## Risks / Trade-offs

- A hook can change anything in the fake client, so a pass may hide a gap → the step result says a hook ran, and the docs say a hook pass proves what the hook checks.
- The API may need more than this slice → it is additive; #273 grows it.
