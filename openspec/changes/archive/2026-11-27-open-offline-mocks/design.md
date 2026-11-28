## Context

`Runner.MOCKABLE` in `tools/entry_runner.lua` is a closed list. A mock is data (args and returns), so the list never guarded against code: it keeps a plan from replacing the functions the runner and the fake client depend on, and from faking a pass. At level 5 the runner already holds the client's measured surface (`tools/clients/<client>.json`, about 5600 names on Era), and `tests/harness.lua` already knows which of those are Lua's own (`LUA_BASE`, `luaAlias`).

CTProbe records a fixed `FIXTURES` list and the armed windows. `ct recordings` turns its saved variables into `tools/recordings/<client>.json`, the only file the runner reads.

## Goals / Non-Goals

**Goals:**
- A developer can mock any game call their addon reads, offline, with answers recorded from their own game.
- Recordings live in the developer's repository, not in the bundle.

**Non-Goals:**
- Sending a developer's recordings back to CheckThat's own `tools/recordings` (#277).
- Recording a call that needs a window open, other than the armed windows CTProbe has today.
- Publishing CTProbe on CurseForge or Wago.

## Decisions

- **Open by the surface, at level 5.** The surface exists only at level 5, so the open rule needs it. A plan below level 5 keeps the closed list, so no old result changes; a plan that used to fail the load now runs, which the compatibility rules allow (a looser check needs no new level). Alternative: a new level 7. Rejected: it changes nothing a level 5 plan already relies on.
- **Deny Lua and the fake client's model.** `H.luaFunction(name)` reports Lua's base functions and the aliases `luaAlias` maps (not the game helpers such as `Mixin` and `date`, which an addon may want to fix). The runner adds `Runner.UNMOCKABLE`: the taint, frame, combat, error-handler and timer functions the fake client models. A dotted name in a Lua table (`string.format`) is Lua's.
- **The error keeps its text.** A refused mock still fails with "mock X is not on the allow list", so the tools and tests that read it keep working.
- **`recordings` is a folder, resolved like `toc`.** `ct recordings -o <folder>` already writes `<folder>/<client>.json`, so the same folder serves both. `ct.py offline` resolves it inside the addons folder and refuses a path that leaves it, as for `toc`. The addon's entry wins over the bundled one for the same label, because it is the developer's newer measurement.
- **Name-prefix allow list in CTProbe (option A).** Get, Is, Has, Can and Num, and Unit reads, cover nearly every read-only call without a list to keep. `GetQuestReward` is the one such name known to act (it takes a quest reward), so it is blocked. A protected function called from an addon is blocked by the game itself.
- **Arguments are parsed, never loaded.** The probe splits the text on commas outside quotes and reads each part as a literal. It stores the arguments with the call (the same `args` field the auction capture uses), so `ct recordings` reads text with spaces exactly.
- **Personal values by type only.** A unit argument for which `UnitIsPlayer` is true, or a return equal to or containing the character's name, realm, normalized realm, money or GUID, makes the whole call type only. `ct recordings` already leaves such calls out.
- **No silent write into the plugin cache.** An installed bundle is replaced on update, so `ct recordings` without `-o` stops there.

## Risks / Trade-offs

- A Get-named function that acts and is not on the block list → the player runs the command by hand, the probe is a development addon, and the block list can grow without a format change.
- Mocking more functions can hide fidelity gaps of the fake client → mocks are reported on each step, as before.
- A developer's recording may differ from the signatures in `signatures.json` → `ct recordings` prints the differences, as it does today.
