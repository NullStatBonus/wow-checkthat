# Design

## Context

`Evidence.Probe(a, env)` is the closed registry behind a `state` assertion, and `env` is `Adapter.Env()`: the few game reads `Model/` gets, each wrapped in `pcall`. Every other global falls through to `_G` unguarded, so a probe that reads a global directly would raise in the game when a client does not have it. `Env()` wraps seven functions today and no read answers nil for a secret value.

## Goals / Non-Goals

**Goals:**
- Four probes that settle a step from the game state alone, with the operators a fact check already has.
- Every read guarded: a missing function, a raising call and a secret value are unknown, never a guess.
- The client's spelling of a call stays in `Adapter.lua`, so `Model/` asks for one name.

**Non-Goals:**
- `bind-location` and `in-combat` (the rest of #67). They are a later change with the same shape.
- Writing anything: no probe sets, closes or moves a frame, a bag or a setting.
- Per-bag details in the results. A probe saves one value, so a sum stays a sum.
- Listing `money`, `bag-free-slots` and `item-count` on the start screen. They read numbers, not player text.

## Decisions

- **The probe answers, `Evidence` compares.** Each probe returns one plain Lua value. `Evidence.CheckState` already applies the operators, `missing`/`exists`, the pattern guard and the `observed` record, so a probe adds no judgment of its own.
- **The adapter picks the spelling.** `env.ContainerFreeSlots` and `env.ItemCount` ask `C_Container`/`C_Item` first and the bare global second, by whether the function exists, never by the client's name. Both census manifests (`tools/clients/`) list the functions on the API tables and not as bare globals on Forever; Era still lists `GetItemCount` as a global.
- **One guard for every wrapped read.** `call` and `callName` return nil when `issecretvalue` says the answer is hidden. This also covers the reads that existed before (build, name, realm, time, date): a hidden answer is already unknown to them, and no test or plan depends on reading one.
- **Secret reads are nil, not an error.** The game hides protected values; a plan cannot compare them, so the step stays unverified and says `value unavailable`. That matches a missing global today.
- **A partial sum is nil.** Bags 0 to 4 are read one at a time; if any is unreadable the total is unknown, so the check is unverified. A total of the bags that answered would be a smaller number, and `ge` would then pass for a player who is out of space.
- **`bag` names one bag.** Bags 0 to 4 are the backpack and the four bag slots; a negative number is the bank (`-1` and lower), which answers only while the bank is open. Without `bag`, the five bags are summed, which is what a "is there room" check wants.
- **`id` is required and numeric.** `C_Item.GetItemCount` accepts an item id, an item string or a link, and a nil reads as the whole inventory on some clients. The plan format therefore takes one number, and validation refuses `item-count` without it.
- **`frame-text` cuts to 80 characters.** `Evidence.VALUE_LEN` is the length every value in a check detail already uses, so the text a check shows, matches and saves has one limit. A frame that is not text (a texture, a slider) reads nil.
- **The frame a `frame-text` check reads is listed on the start screen.** What a frame says can hold player text, and `observed` saves it with a failed or unverified check. The list already exists for `global-value` names; a `frame-shown` check stays out, as before, because it saves only true or false.
- **No plan revision.** A plan that uses a new probe is refused by an older reader as an unknown probe, which is the answer `needs` would give. No key changes meaning, so `Plan.REV` stays 2.

## Testing approach

Each probe has a fake-environment test for its value, for a missing function and for an unknown answer, plus a test for the adapter's guard: a missing function, a raising call, a secret value, and the older global when the API table is absent. Each read was broken once to see its test fail. `tests/test_plan.lua` covers the validation of `id` and `bag`, and `tests/test_app.lua` the start screen list.

## Risks / Trade-offs

- [A packet-hidden value reads as unknown] -> that is the contract: never a guess. The card says `value unavailable`, and the step stays unverified.
- [The bank does not answer out of combat] -> `docs/authoring-plans.md` says a bank bag answers only while the bank is open, and the step that checks it opens the bank.
- [A frame's text is player text] -> the start screen lists the frame, and the results note says a string can include what a plan reads.
