# CTProbe

A development probe, not shipped. It measures the client behaviour that `tests/harness.lua` models, and the results go in `docs/contracts.md`. v2 measured the combat state driver, anchoring protected frames and taint from a replaced global (issue 98). v3 adds the measurements the offline fake client still lacks. v4 adds armed window capture. v5 records two of each window (a gear vendor, a class trainer), money and item info beside them, and auction links (#240). v7 lets the last update of an opening win, skips trainer header rows, records the trainer's kind and filter, waits for complete auction rows, clears old window rows at arm, and adds `/ctp record status`. v8 keeps table returns three levels deep, stores table arguments, and records Forever's auction house (`browse`, `itemsearch`, `commodity`) (#234).

Install by copying `tools/ctprobe/CTProbe` into the game's `Interface/AddOns` folder, on Classic Era and on WoW Forever. It writes `CTProbeDB` to saved variables; run `ct.py collect` afterwards and read `CTProbeDB.log` and `CTProbeDB.fixtures`.

| Command | Issue | What it measures |
|---|---|---|
| (always on) `/ctp life` | 163 | Every lifecycle event in order with its arguments and `IsLoggedIn()`: ADDON_LOADED, VARIABLES_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_LEAVING_WORLD, PLAYER_LOGOUT, ADDONS_UNLOADING, SPELLS_CHANGED. Log in, `/reload`, then log out. The first line says whether `CTProbeDB` exists at file scope. |
| `/ctp tooltip` | 151 | Whether the `OnTooltipSetItem` script hook, the `TooltipDataProcessor` post call, both or neither fire for an item tooltip; whether GameTooltip is shown after SetOwner, SetText and AddLine. |
| `/ctp taint hook`, `/ctp taint hookerror` | 154 | Whether `hooksecurefunc` taints the name it hooks, whether the hook gets the call's arguments, and whether a throwing hook changes what the original returns. |
| `/ctp taint on` | 154 | Replaces `GetMoney`. Open a vendor and buy, out of combat and in combat: the `ADDON_ACTION_BLOCKED` lines show whether a tainted global blocks a protected action. `/ctp taint off` puts it back. |
| `/ctp budget` (`force`) | 190 | How long a plain loop and a loop with a call each turn run in doubling sizes, until the next stage would pass 4 s (30 s with `force`: the game may freeze that long), or the game stops the script. The log gives the rates and the cost of a call in loop turns. |
| `/ctp record` | 153 | What a list of read-only calls returns, in `CTProbeDB.fixtures`. Money, item counts, names and the realm are recorded by type only. It also asks the client for two candidate items (an armor and a weapon) and records them when they arrive. |
| `/ctp record status` | 240 | Names the scenes recorded and those still waiting. |
| `/ctp record arm` | 231, 240 | Waits for two vendors, two trainers and an auction list, and records each window's item count and first rows once (`window` tag in `CTProbeDB.fixtures`). A vendor that sells armor or weapons fills the `gear` scene and another vendor the plain one; a class trainer fills the `class` scene (ten rows, for the ranks) and a profession trainer the plain one. A second scene's labels start with its name (`gear:GetMerchantItemInfo(1)`). One opening of a window fills one scene: close it and open the next vendor or trainer. Each vendor and trainer also records `GetMoney` with its value (`gear:GetMoney()`), and each vendor row's item its `GetItemInfo` and `C_Item.GetItemInfo`. Run `/ctp record` first. Open the windows, search the auction house, then `/reload`. It calls only read-only functions, never one that buys or bids. |
| `/ctp taint run`, `now`, `build` | 98 | The v2 probes. |

CTProbe is not published and is not in the skill bundle: the maintainer runs it and commits the results. Plan authors use the recordings already in `tools/recordings/`. Making the probe available to authors, and recording any read-only call, is a backlog item (#214).

`tests/test_ctprobe.lua` runs every command in the fake client, so the probe itself is tested; it does not test what the game answers. `../wow-ctprobe/CTProbe` is an installed copy: copy the folder again after a change.
