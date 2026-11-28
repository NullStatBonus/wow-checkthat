# Proposal

## Why

Issue #67: a `state` assertion reads a global value, whether an addon is loaded and whether a frame is shown. A plan cannot check what a frame says, the free bag slots, the money or an item count without the addon writing a log line for it. Issue #11 asked for a read-only `/dump`, but chat output is not evidence: a probe is read by CheckThat and compared by the existing operators, so the step settles itself.

## What Changes

- Four read-only `state` probes, each closed and read-only, none protected:
  - `money` reads `GetMoney()`, the balance in copper.
  - `bag-free-slots` reads `C_Container.GetContainerNumFreeSlots`, or the older global `GetContainerNumFreeSlots`, summed over bags 0 to 4, or for the one bag an assertion names in `bag`.
  - `item-count` reads `C_Item.GetItemCount`, or the older global `GetItemCount`, for the item an assertion names in `id`.
  - `frame-text` reads a named frame's `GetText`, cut to 80 characters.
- A probe answers nil, never a guess: a missing function, a raising call and a value the game hides (`issecretvalue`) are unknown, and so is a free-slot sum with one unreadable bag.
- `CheckThat/Core/Adapter.lua` gains the guarded reads for these calls, and the `issecretvalue` guard for every wrapped read. The client's spelling of a function (API table or older global) stays in the adapter.
- The plan format gains the optional `id` and `bag` fields of a `state` assertion, in `CheckThat/Model/Plan.lua`, the schema and `tools/ct.py`.
- The start screen and the debug report name the frame a `frame-text` check reads, as they name a `global-value` name, because what it says can reach the results string.

## Capabilities

### Modified Capabilities
- `test-plan-format`: the closed registry of probes, the `id` and `bag` fields, and how an unknown answer reads.
- `test-runner-ux`: the start screen lists the frames a `frame-text` check reads.
- `debug-tools`: `Plan reads:` names them too.

## Impact

`CheckThat/Core/Adapter.lua`, `CheckThat/Model/Evidence.lua`, `CheckThat/Model/Plan.lua`, `CheckThat/Model/App.lua`, `schema/test-plan.schema.json`, `tools/ct.py`, tests, `README.md`, `docs/authoring-plans.md`, `docs/features.md`, `docs/contracts.md`, `docs/results-format.md`. Additive: no plan, saved variable or results key changes, and a plan that uses a probe needs no higher plan revision because an older reader refuses an unknown probe.
