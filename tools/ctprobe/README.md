# CTProbe

A development addon that calls the game and saves what it answers. Plan authors use `/ctp record <call>` to record a call their addon reads, for offline mocks ([Record your own calls](../../docs/authoring-plans.md#record-your-own-calls)). The maintainer also uses it to measure the client behaviour that `tests/harness.lua` models; those results go in `docs/contracts.md` and `tools/recordings/`.

It ships in the skill bundle, the plugin and the toolkit zip (`ct/tools/ctprobe/CTProbe`). It is not on CurseForge or Wago.

Install by copying the `CTProbe` folder into the game's `Interface/AddOns` folder, on Classic Era and on WoW Forever. It writes `CTProbeDB` to `WTF/Account/<account>/SavedVariables/CTProbe.lua` at `/reload` or logout. Turn recorded calls into a recording file with `ct recordings --src "<that CTProbe.lua>" -o recordings --merge`. The log is in `CTProbeDB.log`.

| Command | Issue | What it measures |
|---|---|---|
| (always on) `/ctp life` | 163 | Every lifecycle event in order with its arguments and `IsLoggedIn()`: ADDON_LOADED, VARIABLES_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_LEAVING_WORLD, PLAYER_LOGOUT, ADDONS_UNLOADING, SPELLS_CHANGED. Log in, `/reload`, then log out. The first line says whether `CTProbeDB` exists at file scope. |
| `/ctp tooltip` | 151 | Whether the `OnTooltipSetItem` script hook, the `TooltipDataProcessor` post call, both or neither fire for an item tooltip; whether GameTooltip is shown after SetOwner, SetText and AddLine. |
| `/ctp taint hook`, `/ctp taint hookerror` | 154 | Whether `hooksecurefunc` taints the name it hooks, whether the hook gets the call's arguments, and whether a throwing hook changes what the original returns. |
| `/ctp taint on` | 154 | Replaces `GetMoney`. Open a vendor and buy, out of combat and in combat: the `ADDON_ACTION_BLOCKED` lines show whether a tainted global blocks a protected action. `/ctp taint off` puts it back. |
| `/ctp budget` (`force`) | 190 | How long a plain loop and a loop with a call each turn run in doubling sizes, until the next stage would pass 4 s (30 s with `force`: the game may freeze that long), or the game stops the script. The log gives the rates and the cost of a call in loop turns. |
| `/ctp record` | 153 | What a list of read-only calls returns, in `CTProbeDB.fixtures`. Money, item counts, names and the realm are recorded by type only. It also asks the client for two candidate items (an armor and a weapon) and records them when they arrive. |
| `/ctp record <call>` | 214 | One call you name, such as `/ctp record GetSpellInfo(133)`. The name must start with Get, Is, Has, Can or Num, or be a Unit read; `GetQuestReward` is refused. Arguments are literal values, never code. A call on a player unit, or one whose returns hold the character's name, realm, GUID or money, is recorded by type only. A later `/ctp record` keeps it. |
| `/ctp record status` | 240 | Names the scenes recorded and those still waiting. |
| `/ctp record arm <scenes>` | 240 | Arms only the named scenes (`gear merchant class trainer auction browse itemsearch commodity`), for a run that confirms a few entries. |
| `/ctp record arm` | 231, 240 | Waits for two vendors, two trainers and an auction list, and records each window's item count and first rows once (`window` tag in `CTProbeDB.fixtures`). A vendor that sells armor or weapons fills the `gear` scene and another vendor the plain one; a class trainer fills the `class` scene (ten rows, for the ranks) and a profession trainer the plain one. A second scene's labels start with its name (`gear:GetMerchantItemInfo(1)`). One opening of a window fills one scene: close it and open the next vendor or trainer. Each vendor and trainer also records `GetMoney` with its value (`gear:GetMoney()`), and each vendor row's item its `GetItemInfo` and `C_Item.GetItemInfo`. Run `/ctp record` first. Open the windows, search the auction house, then `/reload`. It calls only read-only functions, never one that buys or bids. |
| `/ctp taint run`, `now`, `build` | 98 | The v2 probes. |

`tests/test_ctprobe.lua` runs every command in the fake client, so the probe itself is tested; it does not test what the game answers. `../wow-ctprobe/CTProbe` is an installed copy: copy the folder again after a change.

## Versions

v2 measured the combat state driver, anchoring protected frames and taint from a replaced global (issue 98). v3 adds the measurements the offline fake client still lacks. v4 adds armed window capture. v5 records two of each window (a gear vendor, a class trainer), money and item info beside them, and auction links (#240). v7 lets the last update of an opening win, skips trainer header rows, records the trainer's kind and filter, waits for complete auction rows, clears old window rows at arm, and adds `/ctp record status`. v8 keeps table returns three levels deep, stores table arguments, and records Forever's auction house (`browse`, `itemsearch`, `commodity`) (#234). v9 adds `/ctp record <call>` (#214).
